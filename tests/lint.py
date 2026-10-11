#!/usr/bin/env python3
"""Lint and format repository sources without loading the active dotfiles."""

import argparse
import json
import plistlib
import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRETTIER_SUFFIXES = {
    ".md",
    ".json",
    ".jsonc",
    ".yaml",
    ".yml",
    ".html",
    ".js",
    ".cjs",
    ".mjs",
}


def run(*command, **kwargs):
    print("+ " + " ".join(map(str, command)), flush=True)
    return subprocess.run(
        [str(arg) for arg in command],
        cwd=ROOT,
        stdin=None if "input" in kwargs else subprocess.DEVNULL,
        check=True,
        **kwargs,
    )


def source_files():
    paths = (
        subprocess.check_output(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
            cwd=ROOT,
        )
        .decode()
        .split("\0")
    )
    return [
        Path(name)
        for name in sorted(set(paths))
        if name and (ROOT / name).is_file() and not (ROOT / name).is_symlink()
    ]


def sources_by_type(paths):
    groups = {
        key: []
        for key in (
            "python",
            "shell",
            "fish",
            "lua",
            "toml",
            "prettier",
            "markdown",
            "swift",
            "plist",
        )
    }
    suffixes = {
        ".py": "python",
        ".fish": "fish",
        ".lua": "lua",
        ".toml": "toml",
        ".swift": "swift",
        ".tmTheme": "plist",
    }
    for path in paths:
        if path.suffix in suffixes:
            groups[suffixes[path.suffix]].append(path)
        if path.suffix in PRETTIER_SUFFIXES or path.name == ".swift-format":
            groups["prettier"].append(path)
        if path.suffix == ".md":
            groups["markdown"].append(path)
        first_line = (ROOT / path).read_bytes().split(b"\n", 1)[0]
        if path.suffix in {".sh", ".bash"} or first_line in {
            b"#!/usr/bin/env bash",
            b"#!/bin/bash",
        }:
            groups["shell"].append(path)
    return groups


def lint_sources(paths, groups, *, fix=False):
    run("ruff", "check", *(["--fix"] if fix else []), *groups["python"])
    run("ruff", "format", *([] if fix else ["--check"]), *groups["python"])
    run("shellcheck", *groups["shell"])
    run("shfmt", "-w" if fix else "-d", *groups["shell"])
    for path in groups["shell"]:
        run("/bin/bash", "-n", path)
    run("fish_indent", "--write" if fix else "--check", *groups["fish"])
    for path in groups["fish"]:
        run("fish", "--no-config", "--no-execute", path)
    run("luacheck", *groups["lua"])
    run(
        "stylua",
        "--search-parent-directories",
        "--verify" if fix else "--check",
        ".luacheckrc",
        *groups["lua"],
    )
    run("taplo", "check", *groups["toml"])
    run("taplo", "format", *([] if fix else ["--check"]), *groups["toml"])
    run("prettier", "--write" if fix else "--check", *groups["prettier"])
    run("markdownlint-cli2", *groups["markdown"])
    # Language formatters own indentation, including heredocs and Markdown lists.
    run(
        "editorconfig-checker",
        "-no-color",
        "-disable-indent-size",
        *(["-fix"] if fix else []),
        *paths,
    )
    for path in paths:
        if path.suffix == ".py":
            compile((ROOT / path).read_text(), str(path), "exec")
        elif path.suffix == ".toml":
            document = tomllib.loads((ROOT / path).read_text())
            for tool in document.get("tools", {}).values():
                hook = tool.get("postinstall") if isinstance(tool, dict) else None
                script = hook.get("run") if isinstance(hook, dict) else hook
                if script:
                    run("shellcheck", "--shell=sh", "-", input=script, text=True)
                    run("shfmt", "-d", "-ln", "posix", input=script, text=True)
        elif path.suffix == ".json" or path.name == ".swift-format":
            json.loads((ROOT / path).read_text())
        elif path.suffix == ".jsonc":
            run("pyjson5", path, stdout=subprocess.DEVNULL)
        elif path.suffix == ".gitconfig":
            run("git", "config", "--file", path, "--list", stdout=subprocess.DEVNULL)
        elif path.suffix in {".js", ".cjs", ".mjs"}:
            run(
                "esbuild",
                path,
                "--format=esm",
                "--log-level=error",
                "--outfile=/dev/null",
            )
    for path in groups["plist"]:
        source = (ROOT / path).read_bytes()
        formatted = plistlib.dumps(plistlib.loads(source), sort_keys=False)
        if fix:
            (ROOT / path).write_bytes(formatted)
        elif source != formatted:
            raise ValueError(f"{path}: run mise run format to normalize the XML plist")
    if sys.platform == "darwin":
        if fix:
            run("xcrun", "swift-format", "format", "--in-place", *groups["swift"])
        run("xcrun", "swift-format", "lint", "--strict", *groups["swift"])
        for path in groups["swift"]:
            run("xcrun", "swiftc", "-typecheck", path)
    else:
        print(
            "Swift formatting and Apple framework typechecking run in the macOS CI job."
        )
    run(
        "check-jsonschema",
        "--schemafile",
        "tests/schemas/claude-settings.schema.json",
        "conf.d/claude/settings.json",
    )
    run("actionlint")
    run(
        "check-jsonschema",
        "--builtin-schema",
        "vendor.dependabot",
        ".github/dependabot.yml",
    )
    run("/bin/bash", "conf.d/bin/gha-pins", "audit", ".github/workflows")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fix",
        action="store_true",
        help="format sources and apply safe Ruff fixes before checking",
    )
    args = parser.parse_args()
    paths = source_files()
    groups = sources_by_type(paths)
    lint_sources(paths, groups, fix=args.fix)
    print(f"Lint and formatting passed for {len(paths)} repository files.")


if __name__ == "__main__":
    main()
