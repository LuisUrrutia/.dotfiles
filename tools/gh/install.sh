#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin gh

export GH_PROMPT_DISABLED=1
export GIT_TERMINAL_PROMPT=0

installed_extensions="$("$bin_path" extension list | awk '{print $3}')"

if printf '%s\n' "$installed_extensions" | grep -Fxq drogers0/gh-image; then
  "$bin_path" extension remove gh-image
fi

if printf '%s\n' "$installed_extensions" | grep -Fxq github/gh-stack; then
  printf 'GitHub CLI extension already installed: github/gh-stack\n'
else
  printf 'Installing GitHub CLI extension: github/gh-stack\n'
  "$bin_path" extension install github/gh-stack
fi
