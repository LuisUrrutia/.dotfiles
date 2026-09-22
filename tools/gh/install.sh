#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin gh

export GH_PROMPT_DISABLED=1
export GIT_TERMINAL_PROMPT=0

installed_extensions="$("$bin_path" extension list | awk '{print $3}')"

for extension in github/gh-stack drogers0/gh-image; do
  if printf '%s\n' "$installed_extensions" | grep -Fxq "$extension"; then
    printf 'GitHub CLI extension already installed: %s\n' "$extension"
    continue
  fi

  printf 'Installing GitHub CLI extension: %s\n' "$extension"
  "$bin_path" extension install "$extension"
done
