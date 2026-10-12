"""Seed or adopt a regular, history-owned mise configuration."""

import argparse
import hashlib
import os
import re
import subprocess
import sys
import tomllib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "conf.d/setup"))
from runtime import (
    HOME,
    ROOT,
    atomic,
    document,
    git_origin,
    lock,
    mise,
    read_toml,
    regular_parents,
    toml,
)

REPOSITORY = Path(__file__).resolve().parents[1]


def machine_id():
    if sys.platform != "darwin":
        identifier = Path("/etc/machine-id").read_text().strip()
        if not identifier or identifier == "uninitialized":
            raise ValueError("Cannot determine the machine ID; supply --machine")
        return hashlib.sha256((identifier + "\n").encode()).hexdigest()[:12]
    result = subprocess.run(
        ["/usr/sbin/ioreg", "-rd1", "-c", "IOPlatformExpertDevice"],
        capture_output=True,
        check=True,
        text=True,
        timeout=10,
    )
    match = re.search(r'"IOPlatformUUID" = "([^"]+)"', result.stdout)
    if not match:
        raise ValueError("Cannot determine the machine ID; supply --machine")
    return hashlib.sha256(match[1].encode()).hexdigest()[:12]


def seed(repository=REPOSITORY):
    regular_parents(ROOT / "config.toml")
    if ROOT.is_symlink():
        raise RuntimeError(f"Active configuration must be a real directory: {ROOT}")
    result = subprocess.run(
        [
            "git",
            "-C",
            str(repository),
            "ls-files",
            "-z",
            "--",
            "config.toml",
            "miserc.toml",
            "conf.d",
            "tasks",
            "machines",
        ],
        capture_output=True,
        check=True,
        timeout=10,
    )
    for relative in result.stdout.decode().split("\0"):
        if not relative:
            continue
        source = repository / relative
        if not source.is_file() or source.is_symlink():
            raise RuntimeError(f"Seed source must be a regular tracked file: {source}")
        target = ROOT / relative
        regular_parents(target)
        if target.is_symlink():
            raise RuntimeError(
                f"Refusing a symlink in the active configuration: {target}"
            )
        if target.exists():
            continue
        atomic(target, source.read_bytes(), source.stat().st_mode & 0o777)


def repair_screen_lock_check():
    relative = "conf.d/macos/mise.macos.toml"
    path = ROOT / relative
    regular_parents(path)
    if path.is_symlink():
        raise RuntimeError(f"Refusing symlink: {path}")
    settings = read_toml(path)
    check = settings.get("doctor", {}).get("checks", {}).get("screen-lock", {})
    previous = {
        "run": "/usr/sbin/sysadminctl -screenLock status 2>&1 | /usr/bin/grep -q 'delay is 0 seconds'",
        "hint": "Set Require password after screen saver or display is turned off to Immediately in System Settings.",
    }
    if check.get("run") != previous["run"]:
        return
    replacement = read_toml(REPOSITORY / relative)["doctor"]["checks"]["screen-lock"]
    before = path.read_text()
    section = re.search(
        r"(?ms)^\[doctor\.checks\.screen-lock\][ \t]*\n.*?(?=^\[|\Z)", before
    )
    if section is None:
        raise RuntimeError(f"Cannot safely repair the old screen-lock check: {path}")
    updated = section[0]
    for key, value in previous.items():
        if check.get(key) == value:
            updated = re.sub(
                rf"(?m)^([ \t]*{key}[ \t]*=[ \t]*){re.escape(toml(value))}",
                lambda match: match[1] + toml(replacement[key]),
                updated,
            )
            check[key] = replacement[key]
    after = before[: section.start()] + updated + before[section.end() :]
    if tomllib.loads(after) != settings:
        raise RuntimeError(f"Cannot safely repair the old screen-lock check: {path}")
    atomic(path, after, path.stat().st_mode & 0o777)
    print("Updated the screen-lock check.", flush=True)


def repair_terminal_session():
    repairs = {
        "conf.d/setup/runtime.py": [
            ("        start_new_session=True,\n", "        process_group=0,\n"),
            (
                '        MISE_YES="1",\n        GIT_SSH_COMMAND=',
                '        MISE_YES="1",\n        MISE_RAW="1",\n        GIT_SSH_COMMAND=',
            ),
        ]
    }
    for name in ("config", "sync", "update"):
        relative = "tasks/" + name
        header = (REPOSITORY / relative).read_text().split("#MISE raw=true\n")[0]
        repairs[relative] = [(header, header + "#MISE raw=true\n")]
    changed = False
    for relative, replacements in repairs.items():
        path = ROOT / relative
        regular_parents(path)
        if path.is_symlink():
            raise RuntimeError(f"Refusing symlink: {path}")
        before = path.read_text()
        if relative.startswith("tasks/") and re.search(r"(?m)^#MISE raw\s*=", before):
            continue
        after = before
        for previous, replacement in replacements:
            if after.count(previous) > 1:
                raise RuntimeError(
                    f"Cannot safely repair the old terminal handling: {path}"
                )
            after = after.replace(previous, replacement, 1)
        if after != before:
            atomic(path, after, path.stat().st_mode & 0o777)
            changed = True
    if changed:
        print("Updated setup commands to preserve terminal authorization.", flush=True)


def git_settings(record):
    identity = record.get("git", {})
    default = identity.get("default", {})
    accounts = identity.get("accounts", {})
    variables = {
        "git_name": default.get("name", ""),
        "git_email": default.get("email", ""),
        "git_signing_key": default.get("signing_key", ""),
        "git_accounts": " ".join(accounts),
    }
    files = {}
    for name, account in accounts.items():
        if not re.fullmatch(r"[a-zA-Z0-9_-]+", name):
            raise ValueError(f"Invalid Git account name: {name}")
        if not account.get("name") or not account.get("email"):
            raise ValueError(f"Git account {name} needs name and email")
        directories = []
        for directory in account.get("directories", []):
            if not directory.startswith(("~/", "/")) or "\n" in directory:
                raise ValueError(
                    "Git scopes must be absolute or home-relative directories"
                )
            directories.append(str(Path(directory).expanduser().resolve()))
        prefix = f"git_account_{name}_"
        variables.update(
            {
                prefix + "name": account["name"],
                prefix + "email": account["email"],
                prefix + "signing_key": account.get("signing_key", ""),
                prefix + "directories": "\n".join(directories),
            }
        )
        files[f"~/.config/git/account-{name}.gitconfig"] = {
            "source": "conf.d/git/account.gitconfig.tera",
            "template": True,
            "mode": "0600",
        }
    return variables, files


def enroll(args):
    recovery_recipient = None
    if args.recover:
        from backup import unlock

        with lock():
            recovery_recipient = unlock(REPOSITORY)
    current = read_toml(ROOT / "config.local.toml")
    record = read_toml(REPOSITORY / "machines" / f"{args.machine}.toml")
    if args.record:
        record = read_toml(Path(args.record).expanduser())
    if args.adopt:
        git_origin(args.adopt)
        if (ROOT / "config.toml").exists():
            raise RuntimeError(
                "Adopt into a fresh active configuration; existing setup is preserved"
            )
        phases = "plugins,packages,accounts,files,services,firewall,compose,repos,dotfiles,mise-shell-activate,macos-defaults,macos-launchd-agents,linux-systemd-units,user,tools,task,final-hook"
        mise("bootstrap", "--adopt", args.adopt, "--skip", phases, "--yes")
        current = read_toml(ROOT / "config.local.toml")
    else:
        seed()
    machine = current.get("_", {}).get("machine")
    if not machine:
        git_variables, git_files = git_settings(record)
        machine = {
            "id": args.machine,
            "sync": args.sync or "manual",
            "hostname": record.get("hostname", ""),
            "xcode": record.get("xcode", False),
        }
        current.setdefault("_", {})["machine"] = machine
        current.setdefault("vars", {}).update(git_variables)
        current.setdefault("bootstrap", {}).setdefault("files", {}).update(git_files)
        if machine["xcode"]:
            current.setdefault("bootstrap", {}).setdefault("packages", {})[
                "mas:497799835"
            ] = {"os": "macos"}
        if sys.platform == "darwin":
            defaults = (
                current.setdefault("bootstrap", {})
                .setdefault("macos", {})
                .setdefault("defaults", {})
            )
            defaults.setdefault("com.apple.screencapture", {}).setdefault(
                "location", str(HOME / "Pictures/Screenshots")
            )
        current.setdefault("settings", {}).setdefault("history", {}).update(
            sync="manual", allow_plaintext_history=False
        )
        atomic(ROOT / "config.local.toml", document(current))
    elif args.sync and args.sync != machine["sync"]:
        raise ValueError(
            "Edit _.machine.sync in config.local.toml explicitly to change the existing mode"
        )
    if "dotfiles_repository" not in current.get("vars", {}):
        current.setdefault("vars", {})["dotfiles_repository"] = str(REPOSITORY)
        atomic(ROOT / "config.local.toml", document(current))
    choices = ROOT / "miserc.local.toml"
    apps = args.apps.split(",") if args.apps else []
    valid = {
        p.stem.removeprefix("mise.") for p in (ROOT / "conf.d").glob("*/mise.*.toml")
    }
    if any(app not in valid or app in ("macos", "linux") for app in apps):
        raise ValueError(
            "Unknown optional app; use an individual mise.<app>.toml module name"
        )
    if not choices.exists():
        atomic(choices, "env = " + toml(apps) + "\n")
    elif args.apps is not None and read_toml(choices).get("env", []) != apps:
        raise ValueError(
            "Edit miserc.local.toml explicitly to change an existing app selection"
        )
    recipients = ROOT / "conf.d/history/mise.toml"
    if recovery_recipient:
        configured = (
            read_toml(recipients)
            .get("history", {})
            .get("encryption", {})
            .get("recipients", [])
        )
        if configured and recovery_recipient not in configured:
            raise ValueError(
                "Add the recovery recipient to shared history explicitly before recovery"
            )
        if not configured:
            args.recipient = list(
                dict.fromkeys([*(args.recipient or []), recovery_recipient])
            )
    if args.recipient:
        if recipients.exists():
            configured = (
                read_toml(recipients)
                .get("history", {})
                .get("encryption", {})
                .get("recipients", [])
            )
            if configured != args.recipient:
                raise ValueError(
                    "Edit shared history recipients explicitly; enrollment does not rotate keys"
                )
        else:
            atomic(
                recipients,
                "[history.encryption]\nrecipients = " + toml(args.recipient) + "\n",
            )
    os.chmod(ROOT / "config.local.toml", 0o600)
    if args.recipient or args.recover or not args.seed_only:
        import preferences

        preferences.prepare_history()
    if args.recover:
        from backup import recover

        with lock():
            recover(REPOSITORY, machine["id"])
    if args.seed_only:
        print(f"Seeded missing setup sources in {ROOT}; existing files were preserved")
        return
    with lock():
        repair_terminal_session()
    if sys.platform == "darwin":
        with lock():
            repair_screen_lock_check()
        subprocess.run(
            ["/bin/bash", str(REPOSITORY / "conf.d/macos/screen-lock.sh"), "apply"],
            check=True,
            timeout=300,
        )
    subprocess.run(
        ["git", "-C", str(REPOSITORY), "config", "core.hooksPath", ".githooks"],
        check=True,
        stdin=subprocess.DEVNULL,
        timeout=10,
    )
    if args.origin:
        git_origin(args.origin)
        mise("dot", "save")
        mise("dot", "origin", "set", args.origin, "--sync", "manual", "--yes")
    mise("run", "config", "apply")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--machine")
    parser.add_argument(
        "--record", help="Enrollment TOML with git.default and git.accounts"
    )
    parser.add_argument("--apps", help="Comma-separated optional app module names")
    parser.add_argument("--sync", choices=["manual", "automatic"])
    parser.add_argument("--origin", help="Private setup repository URL (HTTPS or SSH)")
    parser.add_argument(
        "--adopt", help="Recover from a private setup repository URL (HTTPS or SSH)"
    )
    parser.add_argument(
        "--recipient",
        action="append",
        help="Public age recipient; repeat for recovery and other machines",
    )
    parser.add_argument("--seed-only", action="store_true")
    parser.add_argument(
        "--recover",
        action="store_true",
        help="Unlock the public password-protected recovery key and stage this machine's encrypted preferences",
    )
    args = parser.parse_args()
    args.machine = args.machine or machine_id()
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]*", args.machine):
        parser.error("machine ID must contain letters, digits, underscores or hyphens")
    enroll(args)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
