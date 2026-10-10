"""Capture changed shared keys; native mise still owns structured deployment."""

import json
from pathlib import Path

from preferences import reject_credentials
from runtime import (ROOT, atomic, document, home_path, native_json, read_state,
                        read_toml, regular_parents, write_state)


def entries(status=None):
    for entry in (status or native_json("dot", "status")).get("edits", []):
        if not entry["edit"].startswith("merge:") or entry["state"] == "skipped":
            continue
        target = home_path(entry["path"])
        source = Path(entry["origin"]["source"])
        declaration = read_toml(entry["origin"]["config"])["dotfiles"][entry["path"] + "/" + entry["edit"].removeprefix("merge:")]
        if declaration.get("template") or declaration.get("merge") is not True:
            continue
        for path in (target, source):
            regular_parents(path)
            if path.is_symlink():
                raise RuntimeError(f"Structured settings must be regular files: {path}")
        if not source.is_relative_to(ROOT) or source.suffix not in (".toml", ".json"):
            raise RuntimeError(f"Unsupported shared settings source: {source}")
        yield target, source


def read(path):
    return read_toml(path) if path.suffix == ".toml" else json.loads(path.read_text())


def owned(shape, value):
    if not isinstance(shape, dict):
        return value
    if not isinstance(value, dict) or set(shape) - set(value):
        raise RuntimeError("A shared setting was removed; review its source or use config discard on the target")
    return {key: owned(child, value[key]) for key, child in shape.items()}


def check(status):
    state = read_state("edits")
    for target, source in entries(status):
        previous = state.get(str(target))
        if previous is None or not target.is_file():
            continue
        current = owned(previous, read(target))
        if current != previous and current != read(source):
            raise RuntimeError(f"Shared keys changed in {target}; run sync or config capture/discard before applying")


def capture(target_filter=None, force=False):
    state = read_state("edits")
    for target, source in entries():
        if target_filter is not None and target != target_filter or not target.is_file():
            continue
        desired = read(source)
        previous = state.get(str(target))
        if previous is None and not force:
            continue
        current = owned(desired if force else previous, read(target))
        if not force and current == previous:
            continue
        if not force and desired not in (previous, current):
            raise RuntimeError(f"Both shared source and live keys changed for {target}; capture or discard explicitly")
        reject_credentials(current, check_keys=False)
        content = document(current) if source.suffix == ".toml" else json.dumps(current, indent=2) + "\n"
        atomic(source, content, source.stat().st_mode & 0o777)
        state[str(target)] = current
        write_state("edits", state)


def remember():
    state = read_state("edits")
    for target, source in entries():
        if target.is_file():
            desired = read(source)
            if owned(desired, read(target)) == desired:
                state[str(target)] = desired
    write_state("edits", state)


def forget(target):
    state = read_state("edits")
    state.pop(str(target), None)
    write_state("edits", state)
