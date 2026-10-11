"""Update declared software; independent maintenance continues after a failure."""

import argparse
import subprocess
import sys
import time

import config
import edits
import preferences
from runtime import HOME, MISE, ROOT, lock, mise, read_state, run, write_state


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
            if (
                not args.ignore_schedule
                and time.time() - stamps.get(name, 0) < interval
            ):
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
                print(
                    f"{name}: failed; continuing independent maintenance",
                    file=sys.stderr,
                )

        step(
            "mise",
            [
                [MISE, "self-update", "--yes", "--minimum-release-age", "3d"],
                [MISE, "upgrade", "--yes"],
            ],
        )
        step(
            "packages",
            [
                [sys.executable, ROOT / "conf.d/setup/packages.py", "upgrade"],
                [MISE, "bootstrap", "packages", "upgrade", "--yes"],
            ],
            86400,
        )
        if sys.platform == "darwin":
            step("autofirma", [[MISE, "run", "setup:autofirma"]], 86400)
        step("github-extensions", [["gh", "extension", "upgrade", "--all"]])
        step(
            "neovim",
            [
                ["nvim", "--headless", "+Lazy! sync", "+qa"],
                [
                    "nvim",
                    "--headless",
                    "+Lazy! build telescope-fzf-native.nvim",
                    "+lua local ok, err = pcall(function() require('telescope').load_extension('fzf') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd.cquit() end",
                    "+qa",
                ],
                [
                    "nvim",
                    "--headless",
                    "+lua if not require('config.blink').ensure() then vim.cmd.cquit() end",
                    "+qa",
                ],
                [
                    "nvim",
                    "--headless",
                    "+lua if not require('config.lsp').update() then vim.cmd.cquit() end",
                    "+qa",
                ],
                [
                    "nvim",
                    "--headless",
                    "+lua if not require('config.treesitter').install() then vim.cmd.cquit() end",
                    "+qa",
                ],
            ],
        )
        step("skills", [["skills", "update", "--global", "--yes"]])
        step("tmux", [["tpack", "update", "all"]])
        step(
            "fish",
            [
                [MISE, "bootstrap", "repos", "update", "--yes"],
                [MISE, "run", "setup:fish"],
            ],
        )
        step(
            "reference-data",
            [
                ["tldr", "--config", HOME / ".config/tlrc/config.toml", "--update"],
                ["uv", "cache", "prune"],
            ],
        )
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
