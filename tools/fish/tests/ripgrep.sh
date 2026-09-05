#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by fixture shells.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
FISH=/opt/homebrew/bin/fish
RGI_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/functions/rgi.fish"
ABBR_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/conf.d/03_abbrs.fish"
PATH_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/conf.d/01_paths.fish"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home"
bin_dir="$tmp_dir/bin"
mkdir -p "$home_dir" "$bin_dir"

printf '%s\n' \
  '#!/bin/sh' \
  'printf "%s|%s\n" "${RIPGREP_CONFIG_PATH-}" "$*" >"$RG_LOG"' \
  >"$bin_dir/rg"
chmod +x "$bin_dir/rg"

interactive_log="$tmp_dir/interactive.log"
raw_log="$tmp_dir/raw.log"

env \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  HOMEBREW_PREFIX="$tmp_dir/homebrew" \
  RGI_FILE="$RGI_FILE" \
  PATH_FILE="$PATH_FILE" \
  INTERACTIVE_LOG="$interactive_log" \
  RAW_LOG="$raw_log" \
  "$FISH" --no-config -c '
    set -e RIPGREP_CONFIG_PATH
    source "$PATH_FILE"
    set -q RIPGREP_CONFIG_PATH
    and exit 1
    set -gx RG_LOG "$INTERACTIVE_LOG"
    source "$RGI_FILE"
    rgi --files
    or exit 1
    set -q RIPGREP_CONFIG_PATH
    and exit 1
    set -gx RG_LOG "$RAW_LOG"
    command rg raw
  '

expected_config="$home_dir/.config/ripgrep/ripgreprc|--files"
if [[ $(<"$interactive_log") != "$expected_config" ]]; then
  printf 'rgi did not scope the personal ripgrep config to its child process\n' >&2
  exit 1
fi

if [[ $(<"$raw_log") != '|raw' ]]; then
  printf 'Raw rg inherited the interactive ripgrep config\n' >&2
  exit 1
fi

env \
  HOME="$home_dir" \
  PATH=/usr/bin:/bin \
  ABBR_FILE="$ABBR_FILE" \
  "$FISH" --no-config --interactive -c '
    source "$ABBR_FILE"
    abbr --show rg | string match -q "abbr -a -- rg rgi"
  ' </dev/null

env HOME="$home_dir" RGI_FILE="$RGI_FILE" "$FISH" --no-config -c '
    source "$RGI_FILE"
    complete -c rg -l files -d "List files to search"
    set -l expected (complete -C "rg --files")
    set -l actual (complete -C "rgi --files")
    test -n "$expected"; and test "$actual" = "$expected"
  ' || {
  printf 'rgi did not inherit ripgrep completions\n' >&2
  exit 1
}
