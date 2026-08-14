#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fish expands the environment variables in this snippet.

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FISH="${FISH_BIN:-$(command -v fish)}"
COMPLETION="$DOTFILES_ROOT/tools/fish/config/.config/fish/completions/dotfiles.fish"

fail() {
  printf 'Dotfiles completion test: %s\n' "$*" >&2
  exit 1
}

complete_for() {
  local commandline="$1"
  COMPLETION="$COMPLETION" TARGET="$commandline" PATH="$DOTFILES_ROOT:/opt/homebrew/bin:/usr/bin:/bin" \
    "$FISH" --no-config -c 'source "$COMPLETION"; complete -C "$TARGET"' \
    </dev/null
}

tool_candidates="$(complete_for 'dotfiles tool apply ')"
[[ "$tool_candidates" == *$'fish'* && "$tool_candidates" == *$'git'* ]] ||
  fail "Tool Apply candidates were not discovered dynamically"

path_candidates="$(complete_for 'dotfiles config diff fish ')"
[[ "$path_candidates" == *'conf.d/03_abbrs.fish'* ]] ||
  fail "eligible Config paths were not discovered"
[[ "$path_candidates" != *'.stow-local-ignore'* ]] || fail "ignored Config metadata was completed"
[[ "$path_candidates" != *'functions/upd.fish'* && "$path_candidates" != *'functions/backup-configs.fish'* ]] ||
  fail "deleted legacy sources were completed from the Git index"
[[ "$path_candidates" != $'\nfish\n' && "$path_candidates" != fish ]] ||
  fail "Config tool candidates leaked into a path position"

opencode_paths="$(complete_for 'dotfiles config diff opencode ')"
[[ "$opencode_paths" != *'AGENTS.md'* ]] ||
  fail "tracked symlink source was offered as a Config path"

finished_tool_candidates="$(complete_for 'dotfiles tool apply fish ')"
[[ -z "$finished_tool_candidates" ]] || fail "Tool names were offered after the complete route"

profile_candidates="$(complete_for 'dotfiles install --profile ')"
[[ "$profile_candidates" == *$'dev'* && "$profile_candidates" == *$'web3'* ]] ||
  fail "Install profiles were not read from profile metadata files"

update_candidates="$(complete_for 'dotfiles update --')"
[[ "$update_candidates" == *'--ignore-schedule'* ]] || fail "Update syntax is absent"

backup_candidates="$(complete_for 'dotfiles backup ')"
[[ "$backup_candidates" == *$'all'* && "$backup_candidates" == *$'raycast'* && "$backup_candidates" == *$'thaw'* ]] ||
  fail "Backup targets are absent"
