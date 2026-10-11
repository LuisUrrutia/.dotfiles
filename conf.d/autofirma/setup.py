"""Prepare the signed AutoFirma installer without waiting on its GUI prompts."""

import hashlib
import io
import json
from pathlib import Path
import platform
import plistlib
import re
import shlex
import subprocess
import sys
import urllib.request
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "setup"))
from runtime import STATE, atomic, regular_parents

CASK = "https://formulae.brew.sh/api/cask/autofirma.json"
APP_INFO = Path("/Applications/AutoFirma.app/Contents/Info.plist")


def current_release():
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise RuntimeError("AutoFirma setup requires macOS arm64")
    with urllib.request.urlopen(CASK, timeout=30) as response:
        cask = json.load(response)
    packages = [installer["manual"] for artifact in cask["artifacts"]
                for installer in artifact.get("installer", []) if "manual" in installer]
    if (not re.fullmatch(r"\d+(?:\.\d+)*", cask["version"])
            or not re.fullmatch(r"[a-f0-9]{64}", cask["sha256"])
            or not cask["url"].startswith("https://")
            or len(packages) != 1
            or Path(packages[0]).name != packages[0]
            or not packages[0].endswith(".pkg")):
        raise RuntimeError("AutoFirma cask must declare a version, HTTPS URL, SHA-256 and one manual package")
    return cask["version"], cask["url"], cask["sha256"], packages[0]


def main():
    version, url, checksum, package = current_release()
    print(f"AutoFirma cask release: {version}")
    if APP_INFO.is_file():
        installed = plistlib.loads(APP_INFO.read_bytes())
        if installed.get("CFBundleIdentifier") == "es.gob.afirma.simpleafirma.osx":
            receipt = subprocess.run(
                ["/usr/sbin/pkgutil", "--pkg-info-plist", "es.gob.afirma"],
                stdin=subprocess.DEVNULL, capture_output=True, timeout=10,
            )
            if receipt.returncode == 0:
                installed_version = plistlib.loads(receipt.stdout)["pkg-version"]
                if tuple(map(int, installed_version.split("."))) >= tuple(map(int, version.split("."))):
                    print(f"AutoFirma {installed_version} is installed")
                    return
    installer = STATE / "installers/autofirma" / version / package
    regular_parents(installer)
    with urllib.request.urlopen(url, timeout=60) as response:
        archive = response.read()
    if hashlib.sha256(archive).hexdigest() != checksum:
        raise RuntimeError("AutoFirma archive checksum does not match its current cask")
    with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
        # Casks use macOS's case-insensitive filenames; ZIP member lookup does not.
        members = [name for name in bundle.namelist() if name.casefold() == package.casefold()]
        if len(members) != 1:
            raise RuntimeError("AutoFirma archive must contain exactly the cask's manual package")
        atomic(installer, bundle.read(members[0]))
    subprocess.run(
        ["/usr/sbin/pkgutil", "--check-signature", str(installer)],
        stdin=subprocess.DEVNULL, check=True, timeout=30,
    )
    # The vendor's postinstall requires GUI interaction even with the CLI installer.
    raise RuntimeError(
        f"Complete AutoFirma's vendor installer: open {shlex.quote(str(installer))}\n"
        "Then rerun mise -C ~ run config apply. Automatic setup remains pending."
    )


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, TypeError, OSError, KeyError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        sys.exit(str(error))
