---
name: fzf-fish-debugging
description: Debugs fzf and fzf.fish integration in this macOS Fish dotfiles repo, including Fisher plugin loading, key bindings, previews, FZF_DEFAULT_OPTS, fzf.fish variables, and Fish config side effects. Use when fzf, fzf.fish, Ctrl-R/Ctrl-Alt bindings, previews, search syntax, ripgrep reloads, or Fish/fzf integration behaves incorrectly.
---

# fzf.fish Debugging

## Quick Start

Separate fzf core from PatrickF1/fzf.fish before editing. fzf core provides `fzf --fish | source`; fzf.fish is a Fisher plugin with its own functions, bindings, and variables. Do not mix fixes unless the evidence shows both are active and conflicting.

Run the first probe set:

```sh
fish -n tools/fish/config/.config/fish/config.fish
fish -c 'command -q fzf; and fzf --version'
fish -c 'command -q fisher; and fisher list'
fish -c 'functions -q _fzf_search_history; and echo loaded'
fish -c 'bind | string match "*_fzf*"'
fish -c 'set --show FZF_DEFAULT_OPTS fzf_preview_file_cmd fzf_preview_dir_cmd fzf_history_time_format fzf_diff_highlighter'
```

## Repo Map

- `fzf` and `fisher` are Homebrew-managed tools in this dotfiles setup.
- Main fzf settings live in `tools/fish/config/.config/fish/config.fish`.
- Current settings include `FZF_DEFAULT_OPTS`, `fzf_diff_highlighter`, `fzf_history_time_format`, `fzf_preview_file_cmd`, and `fzf_preview_dir_cmd`.
- `tools/fish/install.sh` runs Fisher update only if `~/.config/fish/fish_plugins` exists.
- fzf.fish generated files are intentionally ignored by Stow, including `functions/fzf_configure_bindings.fish`, `conf.d/fzf.fish`, and `completions/fzf_configure_bindings.fish`.
- Repo functions using fzf include `glogf.fish`, `wtpr.fish`, and `killport.fish`.

## Diagnosis Workflow

1. Reproduce in Fish and record the binding, command, preview, or search query that fails.
2. Prove fzf core works with `printf 'one\ntwo\n' | fzf --filter one`.
3. Prove fzf.fish is loaded with `_fzf_search_*` functions and `_fzf*` bindings.
4. Inspect `bind` and `bind --user` for terminal or user overrides.
5. Inspect fzf variables with `set --show`; universal variables can shadow globals across sessions.
6. If previews show stray text, run `fish -c true`; config output in noninteractive shells leaks into fzf preview panes.
7. Make one minimal config/function change, then rerun the exact failing probe.

## fzf Core Notes

- Official Fish integration is `fzf --fish | source` in `config.fish`.
- Disable Ctrl-T or Alt-C by setting `FZF_CTRL_T_COMMAND` or `FZF_ALT_C_COMMAND` while sourcing, not after.
- Search terms are space-separated; `'term` is exact, `^term` is prefix, `.ext$` is suffix, `!term` is inverse, and `|` is OR.
- For live ripgrep, use `fzf --disabled --ansi --bind 'change:reload:rg --column --color=always --smart-case {q} || :'` and include an initial reload if needed.
- For fielded output, use `--delimiter`, `--nth`, `--with-nth`, `--accept-nth`, and preview placeholders like `{1}`, `{2}`, `{+f}`.
- For multi-line records, prefer NUL-separated input with `--read0`.

## fzf.fish Notes

- fzf.fish default bindings include history, files, git log, git status, processes, and variables.
- fzf.fish requires Fish 4.0.0+ and fzf 0.33.0+; `fd` and `bat` only matter for Search Directory.
- Customize bindings with `fzf_configure_bindings --help`; put persistent calls in `config.fish`.
- Per-command option variables include `fzf_directory_opts`, `fzf_git_log_opts`, `fzf_git_status_opts`, `fzf_history_opts`, `fzf_processes_opts`, and `fzf_variables_opts`.
- Preview command variables are `fzf_preview_file_cmd` and `fzf_preview_dir_cmd`; do not include the target path because fzf.fish supplies it.
- `fzf_diff_highlighter` should not page output. This repo uses `delta --paging=never --width=20`.
- `fzf_history_time_format` must not include the vertical delimiter used internally by fzf.fish.

## Validation Commands

```sh
fish -c 'functions fzf_configure_bindings'
fish -c 'bind --user | string match "*_fzf*"'
fish -c 'set --show FZF_DEFAULT_OPTS FZF_DEFAULT_OPTS_FILE FZF_DEFAULT_COMMAND'
fish -c 'set --show fzf_directory_opts fzf_git_log_opts fzf_history_opts fzf_fd_opts'
printf 'one\ntwo\n' | fzf --filter one
```

## Common Failures

- fzf.fish variables are placed behind the wrong interactive guard and never execute.
- Another fzf plugin or `fzf --fish | source` binding overrides fzf.fish bindings.
- macOS terminal Option/Meta settings swallow Ctrl-Alt bindings before Fish sees them.
- Old plugin config like `fzf_fish_custom_keybindings` indicates a v7 migration issue.
- `fd` or `bat` is missing for Search Directory previews; do not add dependencies without user approval.
- `fd` hides gitignored files; use `fzf_fd_opts --no-ignore` only when that behavior is wanted.
- Old sessions keep stale universal variables; inspect with `set --show` and reopen Fish after changes.

## Change Rules

- Do not add `fzf.fish`, Brewfile entries, generated plugin files, or dependencies unless explicitly requested.
- Keep plugin-generated files ignored; edit tracked config or tracked wrapper functions instead.
- Preserve existing Catppuccin fzf styling unless the user asks for visual changes.
- Always validate both core fzf behavior and Fish plugin loading before claiming the integration is fixed.

## Sources

- fzf shell integration: https://github.com/junegunn/fzf#setting-up-shell-integration
- fzf search syntax/reference: https://github.com/junegunn/fzf#search-syntax
- fzf ripgrep integration: https://github.com/junegunn/fzf#ripgrep-integration
- fzf.fish README: https://github.com/PatrickF1/fzf.fish
- fzf.fish Cookbook: https://github.com/PatrickF1/fzf.fish/wiki/Cookbook
- fzf.fish Troubleshooting: https://github.com/PatrickF1/fzf.fish/wiki/Troubleshooting
