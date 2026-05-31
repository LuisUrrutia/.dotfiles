---
name: fish-completion-debugging
description: Debugs Fish shell completions, completion path loading, autoloading, and shell integration issues in this macOS dotfiles repo. Use when Fish completions, complete commands, fish_complete_path, Homebrew vendor completions, prompt side effects, or tools/fish/config/.config/fish/completions behavior is broken or being changed.
---

# Fish Completion Debugging

## Quick Start

Start with a failing completion transcript, not a guess. Capture the command, cursor position, expected candidates, actual candidates, and whether the problem appears only in interactive shells.

Use this minimum loop:

```sh
fish -n tools/fish/config/.config/fish/config.fish
fish -n tools/fish/config/.config/fish/conf.d/*.fish
fish -n tools/fish/config/.config/fish/completions/*.fish
fish -c 'set --show fish_complete_path'
fish -c 'complete -C "wt "'
```

## Repo Map

- Fish config root: `tools/fish/config/.config/fish`.
- Tracked completions: `tools/fish/config/.config/fish/completions/<command>.fish`.
- Homebrew completion paths are prepended in `conf.d/00_homebrew.fish`.
- Paths and `RIPGREP_CONFIG_PATH` live in `conf.d/01_paths.fish`.
- Interactive abbreviations live in `conf.d/03_abbrs.fish` and should stay guarded.
- `tools/fish/install.sh` Stows config, adds Fish to `/etc/shells`, changes the shell, and runs Fisher update only when `~/.config/fish/fish_plugins` exists.

## Diagnosis Workflow

1. Reproduce with `complete -C "command partial"`; it exercises Fish completion logic without relying on the terminal UI.
2. Inspect `$fish_complete_path`; user completions must be ahead of vendor completions when overriding behavior.
3. Confirm the file name matches the command exactly: `<command>.fish`.
4. Read the completion file and verify `complete -c`, `-a`, `-n`, `-f`, `-F`, `-d`, and command substitutions match Fish syntax.
5. Check command availability inside Fish with `fish -c 'command -q tool; echo $status'`.
6. Check interactive guards. `config.fish` runs in all Fish shells, including noninteractive preview shells, so anything producing output or requiring a TTY must be under `status is-interactive`.
7. For deeper failures, use `fish --debug='complete,*history*'`, `fish --no-config`, `fish_indent --check file.fish`, and `fish_key_reader` before editing.
8. Make the smallest completion/config change, then rerun the exact failing `complete -C` probe.

## Completion Rules

- Fish completions use `complete -c <command> ...`; do not write Bash/Zsh completion syntax.
- Fish offers files by default. Use `-f` to disable files and `-F` to force files back for a specific completion.
- Dynamic candidates belong in `-a '(...)'`; candidates can include descriptions separated by tabs.
- Conditions belong in `-n`, commonly using helpers like `__fish_seen_subcommand_from`.
- Command substitutions split on newlines, not POSIX words. Avoid Bashisms: backticks, `[[ ]]`, `${var}`, and unquoted empty-variable tests.
- Prefer `command -q`, `set -q`, `string length -q -- "$var"`, `argparse`, `status`, and `and`/`or`.

## Validation Commands

Use a temporary home for Stow checks so the user's live config is not touched:

```sh
tmp_home="$(mktemp -d)"
stow -n -v -d "$PWD/tools/fish" -t "$tmp_home" config
fish -c 'set --show fish_complete_path'
fish -c 'complete -C "wt "'
fish -c 'complete -C "awss "'
fish -c 'functions --details fish_prompt'
fish -c 'status is-interactive; echo $status'
fish_indent --check tools/fish/config/.config/fish/completions/*.fish
```

## Common Failures

- Completion file is named incorrectly, so Fish never autoloads it.
- `$fish_complete_path` does not include the Stowed user completions or Homebrew vendor paths.
- A completion disables files with `-f` but never supplies dynamic candidates.
- A command substitution assumes Bash word splitting or uses Bash-only syntax.
- Noninteractive shells print output from config, breaking SSH/scp/rsync, fzf previews, or completion probes.
- Prompt logic reads `$status` too late; if editing prompts, capture it first thing in `fish_prompt`.

## Change Rules

- Keep Fish indentation at 4 spaces.
- Do not add Brewfile dependencies, generated completions, or Fisher plugins unless the user explicitly asks.
- Do not track ignored plugin-generated files such as `functions/fisher.fish`, `conf.d/fzf.fish`, or `completions/fzf_configure_bindings.fish`.
- Prefer one regression probe per bug: the failing `complete -C` command should fail before the edit and pass after it.

## Sources

- Fish completions: https://fishshell.com/docs/current/completions.html
- Fish commands: https://fishshell.com/docs/current/commands.html
- Fish FAQ: https://fishshell.com/docs/current/faq.html
- Fish interactive behavior: https://fishshell.com/docs/current/interactive.html
- Fish prompt docs: https://fishshell.com/docs/current/prompt.html
