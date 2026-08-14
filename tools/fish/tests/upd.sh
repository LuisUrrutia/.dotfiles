#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fish expands the injected file path.

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ABBR_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/conf.d/03_abbrs.fish"
COMPLETION_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/completions/dotfiles.fish"

fail() {
  printf 'Fish maintenance migration test: %s\n' "$*" >&2
  exit 1
}

[[ ! -e "$DOTFILES_ROOT/tools/fish/config/.config/fish/functions/upd.fish" ]] ||
  fail "legacy Update function still exists"
[[ ! -e "$DOTFILES_ROOT/tools/fish/config/.config/fish/functions/backup-configs.fish" ]] ||
  fail "legacy Backup function still exists"
[[ ! -e "$DOTFILES_ROOT/tools/fish/config/.config/fish/completions/upd.fish" ]] ||
  fail "legacy Update completion still exists"

[[ "$(grep -cF "abbr -a -- upd 'dotfiles update'" "$ABBR_FILE")" -eq 1 ]] ||
  fail "upd is not exactly one canonical abbreviation"
[[ "$(grep -cF "abbr -a -- backup-configs 'dotfiles backup all'" "$ABBR_FILE")" -eq 1 ]] ||
  fail "backup-configs is not exactly one canonical abbreviation"

[[ -f "$COMPLETION_FILE" ]] || fail "canonical Dotfiles completion is missing"
grep -qF "complete -c dotfiles -n '__dotfiles_seen_subcommand update'" "$COMPLETION_FILE" ||
  fail "Dotfiles completion does not own Update syntax"
grep -qF "complete -c dotfiles -f -n __dotfiles_needs_backup_target" "$COMPLETION_FILE" ||
  fail "Dotfiles completion does not own Backup syntax"

if ABBR_FILE="$ABBR_FILE" fish --no-config -c \
  'source "$ABBR_FILE"; abbr -q upd; or abbr -q backup-configs'; then
  fail "maintenance abbreviations leaked into non-interactive Fish"
fi

interactive_abbreviations="$({
  ABBR_FILE="$ABBR_FILE" fish --no-config --interactive -c \
    'source "$ABBR_FILE"; abbr --show'
} 2>/dev/null)"
[[ "$(printf '%s\n' "$interactive_abbreviations" | grep -cF "abbr -a -- upd 'dotfiles update'")" -eq 1 ]] ||
  fail "interactive upd abbreviation does not expand canonically"
[[ "$(printf '%s\n' "$interactive_abbreviations" | grep -cF "abbr -a -- backup-configs 'dotfiles backup all'")" -eq 1 ]] ||
  fail "interactive backup abbreviation does not expand canonically"
