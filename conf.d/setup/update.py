"""Update declared software; independent maintenance continues after a failure."""

import argparse
import os
import shutil
import subprocess
import sys
import time

import config
import edits
import preferences
from runtime import (HOME, MISE, ROOT, lock, mise, read_state, run, write_state)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ignore-schedule", action="store_true")
    args = parser.parse_args()
    failures = []
    with lock():
        edits.capture()
        config.check()
        preferences.prepare_history()
        mise("dot", "save")
        stamps = read_state("maintenance")

        def step(name, commands, interval=0):
            if not args.ignore_schedule and time.time() - stamps.get(name, 0) < interval:
                print(f"{name}: skipped (schedule)")
                return
            try:
                for command in commands:
                    run(command)
                stamps[name] = int(time.time())
                write_state("maintenance", stamps)
                print(f"{name}: completed")
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
                failures.append(name)
                print(f"{name}: failed; continuing independent maintenance", file=sys.stderr)

        step("mise", [[MISE, "self-update", "--yes", "--minimum-release-age", "3d"], [MISE, "upgrade", "--yes"]])
        step("packages", [[sys.executable, ROOT / "conf.d/setup/packages.py"],
                            [MISE, "bootstrap", "packages", "upgrade", "--yes"]], 86400)
        step("github-extensions", [["gh", "extension", "upgrade", "--all"]])
        step("rust", [["rustup", "update"]])
        step("neovim", [["nvim", "--headless", "+Lazy! sync", "+qa"],
                        ["nvim", "--headless", "+lua if not require('config.blink').ensure() then vim.cmd.cquit() end", "+qa"],
                        ["nvim", "--headless", "+lua if not require('config.lsp').update() then vim.cmd.cquit() end", "+qa"],
                        ["nvim", "--headless", "+lua if not require('config.treesitter').install() then vim.cmd.cquit() end", "+qa"]])
        step("skills", [["skills", "update", "--global", "--yes"]])
        os.environ["DOTFILES_REAL_GIT"] = shutil.which("git") or "git"
        os.environ["PATH"] = str(ROOT / "conf.d/tmux/git-bin") + os.pathsep + os.environ["PATH"]
        step("tmux", [["tpack", "update", "all"]])
        if sys.platform == "darwin":
            step("fish", [["bash", ROOT / "conf.d/fish/setup.sh"]])
        step("reference-data", [["tldr", "--config", HOME / ".config/tlrc/config.toml", "--update"], ["uv", "cache", "prune"]])
        if sys.platform == "darwin":
            step("cleanup", [["mo", "clean"]], 604800)
        config.remember()
        mise("dot", "save")
    if failures:
        raise RuntimeError("Maintenance failed: " + ", ".join(failures))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
