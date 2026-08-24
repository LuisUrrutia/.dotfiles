#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fish expands the environment variables in this snippet.

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FISH_BIN="${FISH_BIN:-$(command -v fish)}"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude)}"
CLAUDE_COMPLETION="${CLAUDE_COMPLETION:-$DOTFILES_ROOT/tools/fish/config/.config/fish/completions/claude.fish}"

claude_help="$("$CLAUDE_BIN" --help 2>&1)"

expected_options="$(printf '%s\n' "$claude_help" | awk '
  /^Options:$/ { in_options = 1; next }
  /^Commands:$/ { in_options = 0 }
  in_options && /^  -/ {
    line = $0
    while (match(line, /--[[:alnum:]][[:alnum:]-]*/)) {
      print substr(line, RSTART + 2, RLENGTH - 2)
      line = substr(line, RSTART + RLENGTH)
    }
  }
' | sort -u)"

expected_commands="$(printf '%s\n' "$claude_help" | awk '
  /^Commands:$/ { in_commands = 1; next }
  in_commands && /^[^ ]/ { in_commands = 0 }
  in_commands && /^  [a-z]/ {
    line = substr($0, 3)
    split(line, fields, /[[:space:]]+/)
    count = split(fields[1], names, /\|/)
    for (item_index = 1; item_index <= count; item_index++) print names[item_index]
  }
' | sort -u)"

if [[ -z "$expected_options" || -z "$expected_commands" ]]; then
  printf 'Claude completion drift: unable to parse claude --help\n' >&2
  exit 1
fi

completion_path="$(dirname "$CLAUDE_BIN"):$PATH"
option_candidates="$(COMPLETION="$CLAUDE_COMPLETION" TARGET='claude --' PATH="$completion_path" \
  "$FISH_BIN" --no-config -c 'source "$COMPLETION"; and complete -C "$TARGET"' </dev/null | cut -f1)"
command_candidates="$(COMPLETION="$CLAUDE_COMPLETION" TARGET='claude ' PATH="$completion_path" \
  "$FISH_BIN" --no-config -c 'source "$COMPLETION"; and complete -C "$TARGET"' </dev/null | cut -f1)"

drift=false
while IFS= read -r option; do
  if ! grep -Fx -- "--$option" <<<"$option_candidates" >/dev/null; then
    printf 'Claude completion drift: missing option --%s\n' "$option" >&2
    drift=true
  fi
done <<<"$expected_options"

while IFS= read -r subcommand; do
  if ! grep -Fx -- "$subcommand" <<<"$command_candidates" >/dev/null; then
    printf 'Claude completion drift: missing subcommand %s\n' "$subcommand" >&2
    drift=true
  fi
done <<<"$expected_commands"

[[ "$drift" != true ]]
