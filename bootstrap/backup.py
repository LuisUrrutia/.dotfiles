"""Export encrypted preferences to the public checkout and unlock recovery keys."""

import argparse
import json
import plistlib
import re
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "conf.d/setup"))
import preferences
from runtime import (
    MISE,
    ROOT,
    atomic,
    local,
    lock,
    read_state,
    regular_parents,
    write_state,
)

REPOSITORY = Path(__file__).resolve().parents[1]


def age(tool, *args, input=None, prompt=False):
    if prompt:
        try:
            with open("/dev/tty", "rb"):
                pass
        except OSError as error:
            raise RuntimeError(
                "Run this command in a terminal for age's hidden password prompt"
            ) from error
    executable = shutil.which(tool)
    command = [executable] if executable else [MISE, "exec", "age@latest", "--", tool]
    # Keep the controlling terminal for age; key material only crosses pipes.
    result = subprocess.run(
        [*command, *map(str, args)],
        input=input,
        stdin=None if input is not None else subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=None if prompt else subprocess.PIPE,
        timeout=600,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(
            f"{tool} failed (exit {result.returncode}); check the password, key and encrypted input"
        )
    return result.stdout


def read_file(path):
    regular_parents(path)
    if path.is_symlink() or not path.is_file():
        raise RuntimeError(f"Expected a regular file: {path}")
    return path.read_bytes()


def recipient(key):
    public = age("age-keygen", "-y", input=key).decode().strip()
    if not re.fullmatch(r"age1[a-z0-9]+", public):
        raise RuntimeError("Recovery requires one native age identity")
    return public


def public_recipient(repository=REPOSITORY):
    public = read_file(repository / "backups/recovery.pub").decode().strip()
    if not re.fullmatch(r"age1[a-z0-9]+", public):
        raise RuntimeError("Invalid public recovery recipient")
    return public


def identity(repository=REPOSITORY):
    key = read_file(ROOT / "age.txt")
    if recipient(key) != public_recipient(repository):
        raise RuntimeError(
            "The local age identity does not match this checkout's recovery key"
        )
    return key


def recovery_identity(repository=REPOSITORY):
    path = repository / "backups/recovery.age"
    read_file(path)
    key = age("age", "--decrypt", path, prompt=True)
    if recipient(key) != public_recipient(repository):
        raise RuntimeError("The encrypted recovery key and public recipient differ")
    return key


def initialize(repository=REPOSITORY):
    public = repository / "backups/recovery.pub"
    sealed = repository / "backups/recovery.age"
    for path in (public, sealed):
        regular_parents(path)
        if path.exists() or path.is_symlink():
            raise RuntimeError(
                "Recovery is already initialized; use backup unlock on a new machine"
            )
    target = ROOT / "age.txt"
    regular_parents(target)
    if target.is_symlink():
        raise RuntimeError(f"Refusing symlink: {target}")
    key = read_file(target) if target.exists() else age("age-keygen")
    public_key = recipient(key)
    encrypted = age("age", "--armor", "--passphrase", input=key, prompt=True)
    atomic(target, key)
    atomic(sealed, encrypted, 0o644)
    atomic(public, public_key + "\n", 0o644)
    print(
        "Created backups/recovery.age and recovery.pub; the unencrypted identity stays in ~/.config/mise/age.txt"
    )


def unlock(repository=REPOSITORY):
    target = ROOT / "age.txt"
    regular_parents(target)
    if target.exists() or target.is_symlink():
        identity(repository)
    else:
        atomic(target, recovery_identity(repository))
    return public_recipient(repository)


def scope_name(definition, identifier):
    return "shared" if definition["scope"] == "shared" else identifier


def archive_path(repository, scope):
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]*", scope):
        raise ValueError("Invalid backup scope")
    path = repository / "backups/preferences" / f"{scope}.plist.age"
    regular_parents(path)
    return path


def read_archive(path, key, scope, definitions):
    ciphertext = read_file(path)
    if not ciphertext.startswith(b"-----BEGIN AGE ENCRYPTED FILE-----\n"):
        raise RuntimeError(f"Expected an armored age file: {path}")
    decoded = age("age", "--decrypt", "--identity", "-", path, input=key)
    data = plistlib.loads(decoded)
    if (
        not isinstance(data, dict)
        or data.get("format") != 1
        or data.get("scope") != scope
        or not isinstance(data.get("apps"), dict)
    ):
        raise RuntimeError(f"Invalid preference archive: {path}")
    known = {entry["name"]: entry for entry in definitions}
    for name, entry in data["apps"].items():
        definition = known.get(name)
        if (
            not definition
            or (definition["scope"] == "shared") != (scope == "shared")
            or not isinstance(entry, dict)
            or entry.get("major_version") != definition["major_version"]
            or not isinstance(entry.get("files"), dict)
        ):
            raise RuntimeError(f"{name}: review the backup schema before recovery")
        allowed = preferences.snapshot_names(definition)
        for filename, content in entry["files"].items():
            if filename not in allowed or not isinstance(content, bytes):
                raise RuntimeError(f"{name}: unexpected backup file")
            value = (
                plistlib.loads(content)
                if filename.endswith(".plist")
                else json.loads(content)
            )
            preferences.validate(definition, filename, value)
    return data


def capture(repository, identifier, definitions=None):
    archive_path(repository, identifier)
    if identifier == "shared":
        raise ValueError("shared is reserved for portable preferences")
    key = identity(repository)
    read_file(repository / "backups/recovery.age")
    definitions = (
        preferences.definitions(root=repository, all_installed=True)
        if definitions is None
        else definitions
    )
    if not definitions:
        raise RuntimeError(
            "No supported installed applications found; no backup changed"
        )
    catalog = preferences.catalog(repository)
    known = {entry["name"]: entry for entry in catalog}
    prepared = {}
    for definition in definitions:
        scope = scope_name(definition, identifier)
        path = archive_path(repository, scope)
        if scope not in prepared:
            prepared[scope] = (
                read_archive(path, key, scope, catalog)
                if path.exists() or path.is_symlink()
                else {"format": 1, "scope": scope, "apps": {}}
            )
        current = preferences.live(definition, read_links=True)
        if local().get("id") == identifier:
            incoming = preferences.snapshots(definition)
            previous = read_state("preferences").get(definition["name"], {})
            if previous.get("restore") or (
                incoming
                and preferences.fingerprint(incoming) != previous.get("snapshot")
                and incoming != current
            ):
                raise RuntimeError(
                    f"{definition['name']}: incoming restore pending; public backup preserved"
                )
        apps = prepared[scope]["apps"]
        existing = apps.get(definition["name"], {}).get("files", {})
        apps[definition["name"]] = {
            "major_version": definition["major_version"],
            "files": preferences.merge_snapshots(definition, existing, current),
        }
    for scope, data in prepared.items():
        path = archive_path(repository, scope)
        if path.exists() and read_archive(path, key, scope, catalog) == data:
            print(f"{path.relative_to(repository)}: unchanged")
        else:
            plaintext = plistlib.dumps(data, fmt=plistlib.FMT_BINARY, sort_keys=True)
            encrypted = age(
                "age", "--armor", "--recipient", recipient(key), input=plaintext
            )
            atomic(path, encrypted, 0o644)
            print(
                f"{path.relative_to(repository)}: encrypted {len(data['apps'])} app snapshots"
            )
        for name, entry in sorted(data["apps"].items()):
            print(f"  {name}:")
            if not entry["files"]:
                print("    No preference files in this backup")
            for filename in sorted(entry["files"]):
                print(f"    {filename}")
                if filename in known[name].get("collections", {}):
                    for relative in sorted(plistlib.loads(entry["files"][filename])):
                        print(f"      {relative}")


def recover(repository, identifier):
    if local().get("id") != identifier:
        raise RuntimeError("Recover only into the current enrollment's machine ID")
    preferences.prepare_history()
    key = identity(repository)
    definitions = preferences.catalog()
    known = {entry["name"]: entry for entry in definitions}
    writes = []
    for scope in ("shared", identifier):
        path = archive_path(repository, scope)
        if not path.exists() and not path.is_symlink():
            continue
        data = read_archive(path, key, scope, definitions)
        for name, entry in data["apps"].items():
            definition = known[name]
            incoming = preferences.snapshots(definition)
            if incoming and incoming != entry["files"]:
                raise RuntimeError(
                    f"{name}: another preference snapshot exists; both copies preserved"
                )
            for filename, content in entry["files"].items():
                target = preferences.snapshot_root(definition) / filename
                regular_parents(target)
                writes.append((target, content))
    for target, content in writes:
        atomic(target, content)
    print(
        f"Prepared {len(writes)} preference files for the normal app restore; no live settings changed"
    )


def verify(repository=REPOSITORY):
    key = recovery_identity(repository)
    definitions = preferences.catalog(repository)
    paths = sorted((repository / "backups/preferences").glob("*.plist.age"))
    if not paths:
        raise RuntimeError("No preference archives to verify; run backup capture first")
    for path in paths:
        scope = path.name.removesuffix(".plist.age")
        read_archive(path, key, scope, definitions)
    print(f"Password recovery verified for {len(paths)} encrypted preference archives")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["init", "capture", "unlock", "verify"])
    parser.add_argument(
        "--machine", help="Retain the existing machine ID when capturing"
    )
    parser.add_argument(
        "--daily", action="store_true", help="Capture only if not yet saved today"
    )
    args = parser.parse_args()
    if args.daily and args.action != "capture":
        parser.error("--daily requires capture")
    with lock():
        if args.action == "init":
            initialize()
        elif args.action == "unlock":
            unlock()
            print(
                "Recovery identity is ready locally; its plaintext is excluded from Git"
            )
        elif args.action == "verify":
            verify()
        else:
            from enroll import machine_id

            identifier = args.machine or local().get("id") or machine_id()
            if identifier == "shared":
                parser.error("shared is reserved for portable preferences")
            stamp = {
                "date": date.today().isoformat(),
                "repository": str(REPOSITORY),
                "machine": identifier,
            }
            if args.daily and read_state("public-backup") == stamp:
                print("Public preferences already captured today")
                return
            capture(REPOSITORY, identifier)
            write_state("public-backup", stamp)


if __name__ == "__main__":
    try:
        main()
    except (
        RuntimeError,
        ValueError,
        OSError,
        subprocess.SubprocessError,
        plistlib.InvalidFileException,
    ) as error:
        sys.exit(str(error))
