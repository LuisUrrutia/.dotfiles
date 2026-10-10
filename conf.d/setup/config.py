"""Preserve live files before delegating deployment to mise."""

import argparse
import fnmatch
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import edits
from runtime import (HOME, ROOT, STATE, atomic, digest, home_path, lock, mise, native_json,
                        read_state, read_toml, regular_parents, write_state)


def expand(value):
    return home_path(value)


def entries(status=None):
    status = status or native_json("dot", "status")
    for entry in status["files"]:
        if entry["mode"] in ("track", "track-local") or entry["state"] == "skipped":
            continue
        target = expand(entry["target"])
        source = expand(entry["source"]) if entry.get("source") else None
        if entry["mode"] == "symlink-each":
            declaration = read_toml(entry["origin"]["config"]).get("dotfiles", {}).get(entry["target"], {})
            excludes = declaration.get("exclude", []) if isinstance(declaration, dict) else []
            if source is None or not source.is_dir():
                raise RuntimeError(f"Missing source directory for {target}")
            for file in sorted(source.rglob("*")):
                relative = file.relative_to(source)
                if any(fnmatch.fnmatch(str(relative), pattern) or
                        any(fnmatch.fnmatch(part, pattern) for part in relative.parts)
                        for pattern in excludes):
                    continue
                if file.is_file() or file.is_symlink():
                    yield target / relative, file, "symlink", entry["state"]
        else:
            yield target, source, entry["mode"], entry["state"]


def check():
    status = native_json("dot", "status")
    saved = read_state("deployed")
    for target, source, mode, state in entries(status):
        regular_parents(target)
        if mode == "symlink" and target.is_symlink() and target.resolve() == source.resolve():
            continue
        if not target.exists() and not target.is_symlink():
            continue
        if target.is_symlink():
            raise RuntimeError(f"Foreign link: {target}. Inspect it before config discard.")
        if mode in ("copy", "template", "content") and target.is_file():
            if state == "applied" or digest(target) == saved.get(str(target)):
                continue
        if mode == "permissions":
            continue
        raise RuntimeError(f"Unmanaged or edited target: {target}. Use config capture or discard.")
    for edit in status.get("edits", []):
        target = expand(edit.get("path") or edit["target"])
        regular_parents(target)
        if target.is_symlink():
            raise RuntimeError(f"Refusing an edit through a symlink: {target}")
    edits.check(status)
    override = HOME / ".codex/AGENTS.override.md"
    if override.is_file() and override.stat().st_size:
        print(f"Warning: {override} shadows the managed instructions", file=sys.stderr)
    target = HOME / ".codex/AGENTS.md"
    regular_parents(target)
    if target.exists() or target.is_symlink():
        if not target.is_symlink() or target.resolve() != (HOME / ".agents/AGENTS.md").resolve():
            raise RuntimeError(f"Refusing unowned instruction destination: {target}")
    return status


def remember():
    write_state("deployed", {str(target): digest(target)
                            for target, _, mode, _ in entries()
                            if mode in ("copy", "template", "content") and target.is_file()})
    edits.remember()


def resolve(action, value):
    target = expand(value)
    partial = [(path, source) for path, source in edits.entries() if path == target]
    if partial:
        if len(partial) != 1 or not target.is_file():
            raise RuntimeError("Name one existing target with a single shared merge source")
        backup = STATE / "backups" / str(time.time_ns()) / target.relative_to(HOME)
        atomic(backup, target.read_bytes())
        atomic(backup.with_name(backup.name + ".source"), partial[0][1].read_bytes())
        if action == "capture":
            edits.capture(target, force=True)
        else:
            edits.forget(target)
        check()
        mise("dot", "apply", "--yes")
        remember()
        print(f"Preserved previous target and source at {backup}")
        return
    matching = [(source, mode) for path, source, mode, _ in entries() if path == target]
    if len(matching) != 1:
        raise RuntimeError("Name one managed file, not an entire directory or a partial edit")
    source, mode = matching[0]
    regular_parents(target)
    if not target.exists() and not target.is_symlink():
        raise RuntimeError(f"No existing target to {action}: {target}")
    if target.is_dir() and not target.is_symlink():
        raise RuntimeError("Directories require individual file decisions")
    if action == "capture":
        if mode not in ("copy", "symlink") or source is None or not source.is_file() or target.is_symlink():
            raise RuntimeError("Capture accepts a regular replacement for a file source; edit templates directly")
        if not source.is_relative_to(ROOT) or source.is_symlink():
            raise RuntimeError("Capture source must be a regular active setup file")
    backup = STATE / "backups" / str(time.time_ns()) / target.relative_to(HOME)
    regular_parents(backup)
    backup.parent.mkdir(parents=True, mode=0o700)
    if action == "capture":
        shutil.copy2(source, backup.with_name(backup.name + ".source"))
        atomic(source, target.read_bytes(), source.stat().st_mode & 0o777)
    shutil.move(str(target), str(backup))
    print(f"Preserved previous target at {backup}")
    check()
    mise("dot", "apply", "--yes")
    remember()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["check", "status", "diff", "apply", "capture", "discard"])
    parser.add_argument("path", nargs="?")
    args = parser.parse_args()
    if args.action == "check":
        check()
    elif args.action in ("status", "diff"):
        mise("dot", args.action)
    elif args.action == "apply":
        from sync import apply_setup
        with lock():
            apply_setup(force=True)
    else:
        if not args.path:
            parser.error("capture and discard require a managed file path")
        with lock():
            resolve(args.action, args.path)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
