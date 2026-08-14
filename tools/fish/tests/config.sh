#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by child Fish processes.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
FISH=/opt/homebrew/bin/fish
CONFIG_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/config.fish"
VIM_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/conf.d/02_vim.fish"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home"
mkdir -p "$home_dir"

env \
  HOME="$home_dir" \
  PATH=/usr/bin:/bin \
  LANG=es_CL.UTF-8 \
  PAGER=cat \
  XDG_CONFIG_HOME="$tmp_dir/config" \
  EXPECTED_XDG_CONFIG_HOME="$tmp_dir/config" \
  EDITOR=vi \
  VISUAL=vim \
  CONFIG_FILE="$CONFIG_FILE" \
  VIM_FILE="$VIM_FILE" \
  "$FISH" --no-config -c '
    source "$CONFIG_FILE"
    source "$VIM_FILE"
    test "$LANG" = es_CL.UTF-8
    and test "$PAGER" = cat
    and test "$XDG_CONFIG_HOME" = "$EXPECTED_XDG_CONFIG_HOME"
    and test "$EDITOR" = vi
    and test "$VISUAL" = vim
  '

env \
  HOME="$home_dir" \
  PATH=/usr/bin:/bin \
  CONFIG_FILE="$CONFIG_FILE" \
  VIM_FILE="$VIM_FILE" \
  "$FISH" --no-config -c '
    set -e LANG
    set -e PAGER
    set -e XDG_CONFIG_HOME
    set -e EDITOR
    set -e VISUAL
    source "$CONFIG_FILE"
    source "$VIM_FILE"
    test "$LANG" = en_US.UTF-8
    and test "$PAGER" = less
    and test "$XDG_CONFIG_HOME" = "$HOME/.config"
    and test "$EDITOR" = nvim
    and test "$VISUAL" = nvim
  '

secret_marker="$tmp_dir/secret-sourced"
printf '%s\n' 'command touch "$SECRET_MARKER"' >"$home_dir/secrets.fish"

env \
  HOME="$home_dir" \
  PATH=/usr/bin:/bin \
  CONFIG_FILE="$CONFIG_FILE" \
  SECRET_MARKER="$secret_marker" \
  "$FISH" --no-config -c 'source "$CONFIG_FILE"'

if [[ -e "$secret_marker" ]]; then
  printf 'Noninteractive Fish sourced secrets.fish\n' >&2
  exit 1
fi

env \
  HOME="$home_dir" \
  PATH=/usr/bin:/bin \
  CONFIG_FILE="$CONFIG_FILE" \
  SECRET_MARKER="$secret_marker" \
  "$FISH" --no-config --interactive -c 'source "$CONFIG_FILE"' \
  </dev/null

if [[ ! -e "$secret_marker" ]]; then
  printf 'Interactive Fish did not source secrets.fish\n' >&2
  exit 1
fi
