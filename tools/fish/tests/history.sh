#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fish snippets and history entries stay literal.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
FISH=/opt/homebrew/bin/fish
HISTORY_FILTER="$DOTFILES_ROOT/tools/fish/config/.config/fish/functions/fish_should_add_to_history.fish"

assert_history_policy() {
  local expected_status="$1"
  local commandline="$2"
  local actual_status=0

  "$FISH" --no-config -c \
    'source "$argv[1]"; fish_should_add_to_history "$argv[2]"' \
    -- "$HISTORY_FILTER" "$commandline" || actual_status=$?

  if [[ "$actual_status" -ne "$expected_status" ]]; then
    printf 'History filter returned %s instead of %s for: %q\n' \
      "$actual_status" "$expected_status" "$commandline" >&2
    exit 1
  fi
}

for commandline in \
  'cd . && printf done' \
  'cd .; printf done' \
  'cd missing || printf fallback' \
  'ls | cat' \
  'cd . & printf done' \
  $'cd .\nprintf done' \
  $'cd .\nand printf done' \
  'cd (mktemp -d)' \
  'cd $(mktemp -d)' \
  'ls > listing.txt' \
  'history < commands.txt' \
  'ls "directory;with;semicolons"' \
  'false' \
  'printf done' \
  'git status' \
  'cdrom'; do
  assert_history_policy 0 "$commandline"
done

for commandline in \
  'cd' 'cd .' 'cdi project' 'll -a' 'ls /tmp' \
  'history search build' 'btop' 'clear' 'reset'; do
  assert_history_policy 1 "$commandline"
done

printf 'Fish history policy tests passed\n'
