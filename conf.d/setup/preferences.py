"""Capture encrypted application settings and restore them while apps are closed."""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
import time

from runtime import (HOME, ROOT, STATE, atomic, home_path, local, lock, mise, native_json,
                        read_state, read_toml, regular_parents, run, selected, write_state)


def policy():
    base = read_toml(ROOT / "config.toml")
    entry = base.get("dotfiles", {}).get("~/.config/mise/private/preferences", {})
    parent = base.get("dotfiles", {}).get("~/.config/mise", {})
    if entry.get("mode") != "track" or entry.get("encrypt") is not True or "/private" not in parent.get("exclude", []):
        raise RuntimeError("Preferences require separate encrypted tracking and exclusion from the plaintext setup entry")
    recipients = None
    for config in native_json("config"):
        settings = read_toml(config["path"])
        declarations = settings.get("dotfiles", {})
        private = declarations.get("~/.config/mise/private/preferences")
        parent = declarations.get("~/.config/mise")
        if private is not None and (not isinstance(private, dict) or private.get("encrypt") is not True or private.get("mode") != "track"):
            raise RuntimeError("An override disables encrypted preference tracking")
        if parent is not None and (not isinstance(parent, dict) or "/private" not in parent.get("exclude", [])):
            raise RuntimeError("An override includes private preferences in plaintext setup history")
        encryption = settings.get("history", {}).get("encryption", {})
        if recipients is None and "recipients" in encryption:
            recipients = encryption["recipients"]
        if settings.get("settings", {}).get("history", {}).get("allow_plaintext_history"):
            raise RuntimeError("Plaintext history publication must remain disabled")
    if not recipients:
        raise RuntimeError("Enroll public age recipients and a recovery recipient before capturing preferences")


def prepare_history():
    policy()
    marker = ROOT / "private/preferences/.encryption-policy"
    content = b"Encrypted application preferences, format 1.\n"
    # Mise 2026.10.7 drops recipients from checkpoints without an encrypted file.
    # Seed one before the first checkpoint, even before any app has preferences.
    if marker.exists() and marker.read_bytes() != content:
        raise RuntimeError(f"Unrecognized encrypted history marker: {marker}")
    atomic(marker, content)


def definitions():
    if sys.platform != "darwin":
        return []
    choices = selected()
    result = []
    for path in sorted((ROOT / "conf.d").glob("*/preferences.json")):
        definition = json.loads(path.read_text())
        name = path.parent.name
        if definition.get("optional") and name not in choices:
            continue
        if not (Path("/Applications") / (definition["application"] + ".app")).is_dir():
            continue
        bundle = Path("/Applications") / (definition["application"] + ".app") / "Contents/Info.plist"
        version = plistlib.loads(bundle.read_bytes())["CFBundleShortVersionString"]
        if version.split(".")[0] != str(definition["major_version"]):
            raise RuntimeError(f"{name} {version}: review its preference schema before capture or restore")
        definition["name"] = name
        result.append(definition)
    return result


def export_domain(domain):
    result = run(["/usr/bin/defaults", "export", domain, "-"], capture=True, check=False)
    if result.returncode:
        if b"does not exist" in result.stderr:
            return {}
        raise RuntimeError(f"Unable to export preference domain {domain}")
    # Apple's exporter can emit control characters that strict XML parsers reject.
    normalized = run(["/usr/bin/plutil", "-convert", "binary1", "-o", "-", "--", "-"],
                        input=result.stdout, capture=True)
    return plistlib.loads(normalized.stdout)


def reject_credentials(value, *, check_keys=True):
    if isinstance(value, dict):
        for key, child in value.items():
            words = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", str(key)).lower()
            sensitive = re.search(r"(?:^|[^a-z0-9])(?:passwords?|tokens?|secrets?|licen[cs]es?|registration|credentials?|api[_-]?key)(?:$|[^a-z0-9])", words)
            if check_keys and sensitive:
                raise RuntimeError(f"A preference contains a credential field ({key}); classify it before capture")
            reject_credentials(child, check_keys=check_keys)
    elif isinstance(value, list):
        for child in value:
            reject_credentials(child, check_keys=check_keys)
    elif isinstance(value, str) and re.search(r"-----BEGIN .*PRIVATE KEY-----|\b(?:ghp_|github_pat_|xox[baprs]-|sk-proj-)", value):
        raise RuntimeError("A preference contains credential-like content; exclude it before capture")


def serialize(value):
    reject_credentials(value)
    return plistlib.dumps(value, fmt=plistlib.FMT_BINARY, sort_keys=True)


def validate(definition, filename, value):
    def typed(item, expected):
        return (type(item) in (int, float) if expected == "number"
                else type(item).__name__ == expected)

    def refuse():
        raise RuntimeError(f"{definition['name']}/{filename}: incompatible preference structure; review its schema")

    if filename == "preferences.plist":
        if not isinstance(value, dict) or set(value) - set(definition["keys"]):
            refuse()
        for key, item in value.items():
            if not typed(item, definition["keys"][key]):
                refuse()
    else:
        shape = next((spec for path, spec in definition["files"].items()
                        if Path(path).name == filename), None)
        if not shape or not typed(value, shape["type"]):
            refuse()
        for key, expected in shape.get("fields", {}).items():
            if key not in value and key in shape.get("optional", []):
                continue
            if key not in value or not typed(value[key], expected):
                refuse()
        for key, expected in shape.get("versions", {}).items():
            if value.get(key) != expected:
                refuse()
        for key, expected in shape.get("array_items", {}).items():
            if any(not typed(item, expected) for item in value[key]):
                refuse()
    reject_credentials(value)


def snapshot_root(definition):
    if definition["scope"] == "shared":
        scope = Path("shared")
    else:
        identifier = local().get("id", "")
        if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]*", identifier):
            raise RuntimeError("A stable local machine ID is required for hardware-bound preferences")
        scope = Path("machines") / identifier
    return ROOT / "private/preferences" / scope / definition["name"]


def live(definition):
    records = {}
    if definition["keys"]:
        domain = export_domain(definition["domain"])
        owned = {key: domain[key] for key in definition["keys"] if key in domain}
        validate(definition, "preferences.plist", owned)
        records["preferences.plist"] = serialize(owned)
    for filename in definition["files"]:
        path = home_path(filename)
        regular_parents(path)
        if path.is_symlink():
            raise RuntimeError(f"Application settings must be regular files: {path}")
        if path.is_file():
            raw = path.read_bytes()
            value = plistlib.loads(raw) if path.suffix == ".plist" else json.loads(raw)
            validate(definition, path.name, value)
            records[path.name] = serialize(value) if path.suffix == ".plist" else (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()
    return records


def fingerprint(records):
    digest = hashlib.sha256()
    for name, content in sorted(records.items()):
        digest.update(name.encode() + b"\0" + content)
    return digest.hexdigest()


def snapshots(definition):
    root = snapshot_root(definition)
    regular_parents(root)
    if root.is_symlink():
        raise RuntimeError(f"Preference snapshots must be a regular directory: {root}")
    if not root.exists():
        return {}
    allowed = {Path(p).name for p in definition["files"]}
    if definition["keys"]:
        allowed.add("preferences.plist")
    result = {}
    for path in root.iterdir():
        if path.name not in allowed or not path.is_file() or path.is_symlink():
            raise RuntimeError(f"Unexpected preference snapshot: {path}")
        result[path.name] = path.read_bytes()
    return result


def capture(defs=None):
    state = read_state("preferences")
    for definition in definitions() if defs is None else defs:
        name = definition["name"]
        incoming = snapshots(definition)
        current = live(definition)
        previous = state.get(name, {})
        if incoming and fingerprint(incoming) != previous.get("snapshot"):
            print(f"{name}: incoming restore pending; kept the live settings and snapshot")
            continue
        root = snapshot_root(definition)
        for filename, content in current.items():
            atomic(root / filename, content)
        # A missing app file is not evidence of intended deletion.
        merged = incoming | current
        state[name] = {"snapshot": fingerprint(merged), "live": fingerprint(current)}
        write_state("preferences", state)


def is_running(application):
    result = run(["/usr/bin/pgrep", "-x", application], check=False, capture=True, timeout=10)
    if result.returncode not in (0, 1):
        raise RuntimeError(f"Cannot check whether {application} is running")
    return result.returncode == 0


def restore(defs=None):
    state = read_state("preferences")
    pending = []
    for definition in definitions() if defs is None else defs:
        name = definition["name"]
        incoming = snapshots(definition)
        if not incoming:
            continue
        incoming_hash = fingerprint(incoming)
        previous = state.get(name, {})
        if incoming_hash == previous.get("snapshot"):
            continue
        current = live(definition)
        if previous.get("live") and fingerprint(current) != previous["live"]:
            raise RuntimeError(f"{name}: live settings changed since capture; both versions preserved")
        existing = {key: value for key, value in current.items()
                    if key != "preferences.plist" or plistlib.loads(value)}
        if not previous and existing and current != incoming:
            raise RuntimeError(f"{name}: existing live settings differ; use preferences accept {name} after review")
        if any(is_running(name) for name in [definition["application"], *definition.get("writers", [])]):
            pending.append(name)
            continue
        # Validate the complete app snapshot before the first import.
        parsed = {}
        for filename, content in incoming.items():
            value = plistlib.loads(content) if filename.endswith(".plist") else json.loads(content)
            validate(definition, filename, value)
            parsed[filename] = value
        if "preferences.plist" in parsed:
            value = parsed["preferences.plist"]
            if not isinstance(value, dict) or set(value) - set(definition["keys"]):
                raise RuntimeError(f"{name}: snapshot contains unowned preference keys")
            merged = export_domain(definition["domain"])
            for key in definition["keys"]:
                merged.pop(key, None)
            merged.update(value)
            STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
            with tempfile.NamedTemporaryFile(dir=STATE, suffix=".plist") as temporary:
                temporary.write(plistlib.dumps(merged))
                temporary.flush()
                run(["/usr/bin/defaults", "import", definition["domain"], temporary.name])
        for filename in definition["files"]:
            target = home_path(filename)
            if target.name in incoming:
                atomic(target, incoming[target.name])
        state[name] = {"snapshot": incoming_hash, "live": fingerprint(live(definition))}
        write_state("preferences", state)
        print(f"{name}: restored; open the app when ready")
    if pending:
        raise RuntimeError("Restore pending until these apps are closed: " + ", ".join(pending))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["capture", "restore", "accept", "_capture"])
    parser.add_argument("app", nargs="?")
    args = parser.parse_args()
    if args.action == "_capture":
        policy()
        capture()
        return
    with lock():
        prepare_history()
        if args.action == "capture":
            mise("dot", "save")
            mise("dot", "capture", "--label", "application preferences", "--", sys.executable, __file__, "_capture")
            mise("dot", "save")
        elif args.action == "accept":
            matches = [d for d in definitions() if d["name"] == args.app]
            if len(matches) != 1:
                parser.error("accept needs one installed, enabled app")
            definition = matches[0]
            state = read_state("preferences")
            current = live(definition)
            backup = ROOT / "private/preferences/conflicts" / definition["name"] / str(time.time_ns())
            for filename, content in current.items():
                atomic(backup / filename, content)
            mise("dot", "save")
            state[definition["name"]] = {"live": fingerprint(current)}
            write_state("preferences", state)
            restore(matches)
        else:
            restore()


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
