"""Recover Ghostty's original DMG from Nix when its native download fails."""

import argparse
import hashlib
import io
import json
import lzma
import os
from pathlib import Path
import platform
import re
import struct
import subprocess
import sys
import tempfile
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "setup"))
from runtime import atomic, mise, native_json, read_toml, run

CASK = "https://formulae.brew.sh/api/cask/ghostty.json"
CACHE = "https://cache.nixos.org"
DMG_URL = r"https://release\.files\.ghostty\.org/([0-9]+(?:\.[0-9]+)*)/Ghostty\.dmg"
MAX_SIZE = 512 * 1024 * 1024
NIX32 = "0123456789abcdfghijklmnpqrsvwxyz"


def nix32(value):
    number = int.from_bytes(value, "little")
    return "".join(NIX32[(number >> bit) & 31] for bit in reversed(range(0, len(value) * 8, 5)))


def source_key(checksum):
    # Nix's flat fixed-output path identifies the original DMG, not the repackaged app.
    digest = hashlib.sha256(f"fixed:out:sha256:{checksum}:".encode()).hexdigest()
    digest = hashlib.sha256(f"output:out:sha256:{digest}:/nix/store:Ghostty.dmg".encode()).digest()
    compressed = bytearray(20)
    for index, byte in enumerate(digest):
        compressed[index % 20] ^= byte
    return nix32(compressed)


def fetch(url, limit=MAX_SIZE):
    with urllib.request.urlopen(url, timeout=30) as response:
        if not response.url.startswith("https://"):
            raise RuntimeError("Ghostty download redirected outside HTTPS")
        content = response.read(limit + 1)
    if len(content) > limit:
        raise RuntimeError("Ghostty download exceeds its size limit")
    return content


def checked_hash(content, expected):
    if expected != "sha256:" + nix32(hashlib.sha256(content).digest()):
        raise RuntimeError("Ghostty Nix cache checksum mismatch")


def restore_dmg(archive, info, checksum):
    checked_hash(archive, info["FileHash"])
    if len(archive) != int(info["FileSize"]):
        raise RuntimeError("Ghostty Nix download is incomplete")
    if info["Compression"] == "xz":
        opener = lzma.open
    elif info["Compression"] == "zstd":
        from compression import zstd
        opener = zstd.open
    else:
        raise RuntimeError("Unsupported Ghostty Nix compression")
    with opener(io.BytesIO(archive), "rb") as stream:
        content = stream.read(MAX_SIZE + 1)
    if len(content) > MAX_SIZE or len(content) != int(info["NarSize"]):
        raise RuntimeError("Invalid Ghostty Nix archive size")
    checked_hash(content, info["NarHash"])
    stream = io.BytesIO(content)

    def size():
        value = stream.read(8)
        if len(value) != 8:
            raise RuntimeError("Truncated Ghostty Nix archive")
        return struct.unpack("<Q", value)[0]

    def token(expected):
        if (size() != len(expected) or stream.read(len(expected)) != expected
                or stream.read(-len(expected) % 8) != bytes(-len(expected) % 8)):
            raise RuntimeError("Expected one regular DMG file in the Nix archive")

    for expected in (b"nix-archive-1", b"(", b"type", b"regular", b"contents"):
        token(expected)
    length = size()
    if not 0 < length <= MAX_SIZE:
        raise RuntimeError("Invalid Ghostty DMG size")
    dmg = stream.read(length)
    if len(dmg) != length or stream.read(-length % 8) != bytes(-length % 8):
        raise RuntimeError("Truncated Ghostty DMG")
    token(b")")
    if stream.read(1) or hashlib.sha256(dmg).hexdigest() != checksum:
        raise RuntimeError("Recovered Ghostty DMG does not match the native cask checksum")
    return dmg


def recover(checksum):
    key = source_key(checksum)
    info = dict(line.split(": ", 1) for line in fetch(f"{CACHE}/{key}.narinfo", 65536).decode().splitlines()
                if ": " in line)
    if (info.get("StorePath") != f"/nix/store/{key}-Ghostty.dmg"
            or info.get("CA") != "fixed:sha256:" + nix32(bytes.fromhex(checksum))
            or not re.fullmatch(r"nar/[0-9a-z]{52}\.nar\.(?:xz|zst)", info.get("URL", ""))):
        raise RuntimeError("Nix metadata does not identify the requested Ghostty DMG")
    if not all(0 < int(info[field]) <= MAX_SIZE for field in ("FileSize", "NarSize")):
        raise RuntimeError("Invalid Ghostty Nix download size")
    return restore_dmg(fetch(f"{CACHE}/{info['URL']}", int(info["FileSize"])), info, checksum)


def verify_signature(dmg):
    with tempfile.TemporaryDirectory(prefix="ghostty-signature-") as temporary:
        root = Path(temporary)
        archive = root / "Ghostty.dmg"
        archive.write_bytes(dmg)
        mount = root / "mount"
        mount.mkdir()
        try:
            run(["/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-noautoopen",
                    "-mountpoint", mount, archive], capture=True, timeout=90)
            run(["/usr/bin/codesign", "--verify", "--deep", "--strict", "-R",
                    '=anchor apple generic and identifier "com.mitchellh.ghostty" '
                    'and certificate leaf[subject.OU] = "24VZTF6M5V"',
                    mount / "Ghostty.app"], capture=True, timeout=60)
        finally:
            if os.path.ismount(mount):
                run(["/usr/bin/hdiutil", "detach", mount], capture=True, timeout=30)


def enabled():
    # Explicit native package arguments ignore selectors and pins; leave those to full apply.
    for entry in native_json("config"):
        request = read_toml(entry["path"]).get("bootstrap", {}).get("packages", {}).get("brew-cask:ghostty")
        if request is None:
            continue
        if isinstance(request, str):
            return request == "latest"
        systems = request.get("os", ["macos"])
        systems = [systems] if isinstance(systems, str) else systems
        return (request.get("version", "latest") == "latest" and request.get("state", "present") == "present"
                and "env" not in request and any(system in ("macos", f"macos/{platform.machine()}") for system in systems))
    return False


def install(action):
    if sys.platform != "darwin" or not enabled():
        return
    os.environ.setdefault("MISE_HTTP_DOWNLOAD_TIMEOUT", "2m")
    command = ("bootstrap", "packages", action, "brew-cask:ghostty", "--yes")
    result = mise(*command, capture=True, check=False)
    sys.stdout.buffer.write(result.stdout)
    sys.stderr.buffer.write(result.stderr)
    sys.stdout.flush()
    sys.stderr.flush()
    if result.returncode == 0:
        return
    failed = re.search(DMG_URL, result.stderr.decode(errors="replace"))
    if failed is None:
        result.check_returncode()
    cask = json.loads(fetch(CASK, 1024 * 1024))
    if (cask.get("token") != "ghostty" or cask.get("url") != failed[0]
            or cask.get("version") != failed[1] or not re.fullmatch(r"[0-9a-f]{64}", cask.get("sha256", ""))):
        raise RuntimeError("Ghostty cask metadata changed or is unsupported; retry native setup")
    cache = Path(mise("cache", "path", capture=True).stdout.decode().strip())
    url_hash = hashlib.sha256(cask["url"].encode()).hexdigest()[:12]
    # mise 2026.10.7 uses this URL-keyed archive cache; its retry checks SHA-256 again.
    archive = cache / "system-brew/casks" / f"ghostty-{cask['version']}-{url_hash}-Ghostty.dmg"
    if archive.exists() or archive.is_symlink():
        result.check_returncode()
    print(f"Ghostty {cask['version']}: official download failed; recovering the same DMG from Nix", flush=True)
    dmg = recover(cask["sha256"])
    verify_signature(dmg)
    atomic(archive, dmg)
    print("Ghostty: cask checksum and application signature verified; retrying native installation", flush=True)
    mise(*command)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["apply", "upgrade"])
    try:
        install(parser.parse_args().action)
    except (RuntimeError, ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            sys.stderr.buffer.write(error.stderr)
        sys.exit(str(error))
