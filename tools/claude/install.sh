#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

if ! "$bin_path" which claude >/dev/null 2>&1; then
  echo "Warning: claude is not installed by mise, skipping" >&2
  exit 0
fi

stow_config claude
