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


def repair_https_downloads():
    repairs = {
        "conf.d/setup/packages.py": [
            (
                "        with urllib.request.urlopen(\n"
                '            "https://formulae.brew.sh/api/cask/macfuse.json", timeout=30\n'
                "        ) as response:\n"
                '            version = json.load(response)["version"]\n',
                "        version = json.loads(\n"
                '            download("https://formulae.brew.sh/api/cask/macfuse.json")\n'
                '        )["version"]\n',
            ),
        ],
        "conf.d/autofirma/setup.py": [
            (
                "    with urllib.request.urlopen(CASK, timeout=30) as response:\n"
                "        cask = json.load(response)\n",
                "    cask = json.loads(download(CASK))\n",
            ),
            (
                "    with urllib.request.urlopen(url, timeout=60) as response:\n"
                "        archive = response.read()\n",
                "    archive = download(url, timeout=60)\n",
            ),
        ],
        "conf.d/languages/dotnet-lts.py": [
            (
                "    with urllib.request.urlopen(url, timeout=30) as response:\n"
                "        return json.load(response)\n",
                "    return json.loads(download(url))\n",
            ),
        ],
    }
    changed = False
    for relative, replacements in repairs.items():
        path = ROOT / relative
        regular_parents(path)
        if path.is_symlink():
            raise RuntimeError(f"Refusing symlink: {path}")
        if not path.exists():
            continue
        before = path.read_text()
        after = before
        for previous, replacement in replacements:
            if after.count(previous) > 1:
                raise RuntimeError(f"Cannot safely repair HTTPS downloads: {path}")
            after = after.replace(previous, replacement, 1)
        if after == before:
            continue
        if "from downloads import download\n" not in after:
            if after.count("from runtime import ") != 1:
                raise RuntimeError(f"Cannot safely repair HTTPS imports: {path}")
            after = after.replace(
                "from runtime import ",
                "from downloads import download\nfrom runtime import ",
                1,
            )
        without_import = after.replace("import urllib.request\n", "")
        if "urllib." not in without_import:
            after = without_import
        atomic(path, after, path.stat().st_mode & 0o777)
        changed = True
    if changed:
        print("Updated setup downloads to use system certificate trust.", flush=True)


def repair_public_skills_clone():
    path = ROOT / "conf.d/skills/mise.toml"
    regular_parents(path)
    if path.is_symlink():
        raise RuntimeError(f"Refusing symlink: {path}")
    settings = read_toml(path)
    repo = (
        settings.get("bootstrap", {})
        .get("repos", {})
        .get("~/Projects/LuisUrrutia/skills", {})
    )
    previous = "git@github.com:LuisUrrutia/skills.git"
    if repo.get("url") != previous:
        return
    replacement = "https://github.com/LuisUrrutia/skills.git"
    before = path.read_text()
    if before.count(toml(previous)) != 1:
        raise RuntimeError(f"Cannot safely repair the public skills URL: {path}")
    after = before.replace(toml(previous), toml(replacement), 1)
    repo["url"] = replacement
    if tomllib.loads(after) != settings:
        raise RuntimeError(f"Cannot safely repair the public skills URL: {path}")
    atomic(path, after, path.stat().st_mode & 0o777)
    print("Updated the public skills checkout to use HTTPS.", flush=True)


def repair_setup_hash():
    path = ROOT / "conf.d/setup/sync.py"
    regular_parents(path)
    if path.is_symlink():
        raise RuntimeError(f"Refusing symlink: {path}")
    before = path.read_text()
    previous = '        value.update(str(path.relative_to(HOME)).encode() + b"\\0" + path.read_bytes())\n'
    if previous not in before:
        return
    if before.count(previous) != 1:
        raise RuntimeError(f"Cannot safely repair setup change detection: {path}")
    replacement = (
        "        name = path.relative_to(HOME) if path.is_relative_to(HOME) else path\n"
        '        value.update(str(name).encode() + b"\\0" + path.read_bytes())\n'
    )
    atomic(path, before.replace(previous, replacement, 1), path.stat().st_mode & 0o777)
    print(
        "Updated setup change detection for package sources outside HOME.", flush=True
    )


def repair_autofirma_installer():
    path = ROOT / "conf.d/autofirma/setup.py"
    regular_parents(path)
    if path.is_symlink():
        raise RuntimeError(f"Refusing symlink: {path}")
    if not path.exists():
        return
    before = path.read_text()
    previous = (
        "    # The vendor's postinstall requires GUI interaction even with the CLI installer.\n"
        "    raise RuntimeError(\n"
        '        f"Complete AutoFirma\'s vendor installer: open {shlex.quote(str(installer))}\\n"\n'
        '        "Then rerun mise -C ~ run config apply. Automatic setup remains pending."\n'
        "    )\n"
    )
    if previous not in before:
        return
    if before.count(previous) != 1 or before.count("from runtime import ") != 1:
        raise RuntimeError(f"Cannot safely repair the AutoFirma installer: {path}")
    after = before.replace(
        previous, "    complete_installation(installer, version)\n", 1
    )
    after = after.replace(
        "from runtime import ",
        "from installer import complete_installation\nfrom runtime import ",
        1,
    )
    if "shlex." not in after:
        after = after.replace("import shlex\n", "")
    after = after.replace(
        '"""Prepare the signed AutoFirma installer without waiting on its GUI prompts."""',
        '"""Verify the current AutoFirma package and complete its vendor installation."""',
        1,
    )
    atomic(path, after, path.stat().st_mode & 0o777)
    print(
        "Updated AutoFirma to open its installer during interactive setup.", flush=True
    )


def repair_autofirma_order():
    previous_step = (
        '        if sys.platform == "darwin":\n'
        '            step("autofirma", [[MISE, "run", "setup:autofirma"]], 86400)\n'
    )
    repairs = [
        (
            "conf.d/autofirma/mise.macos.toml",
            '[tasks."setup:autofirma"]\n',
            '[bootstrap.hooks]\nfinal = "mise run autofirma"\n\n[tasks.autofirma]\n',
        ),
        ("conf.d/setup/update.py", previous_step, ""),
    ]
    for relative, previous, replacement in repairs:
        path = ROOT / relative
        regular_parents(path)
        if path.is_symlink():
            raise RuntimeError(f"Refusing symlink: {path}")
        if not path.exists():
            continue
        before = path.read_text()
        if previous not in before:
            continue
        if before.count(previous) != 1:
            raise RuntimeError(f"Cannot safely reorder AutoFirma: {path}")
        after = before.replace(previous, replacement, 1)
        if path.suffix == ".toml":
            tomllib.loads(after)
        else:
            anchor = '        config.remember()\n        mise("dot", "save")\n'
            if after.count(anchor) != 1:
                raise RuntimeError(f"Cannot safely reorder AutoFirma: {path}")
            final_step = previous_step.replace('"setup:autofirma"', '"autofirma"')
            after = after.replace(anchor, anchor + final_step, 1)
            compile(after, str(path), "exec")
        atomic(path, after, path.stat().st_mode & 0o777)
        print(f"Moved AutoFirma to the final step in {relative}.", flush=True)


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
    if not args.seed_only and (ROOT / "config.toml").exists():
        from sync import history_ready

        with lock():
            history_ready()
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
        repair_https_downloads()
        repair_public_skills_clone()
        repair_setup_hash()
        repair_autofirma_installer()
        repair_autofirma_order()
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
