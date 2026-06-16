#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

if ! command -v curl >/dev/null 2>&1; then
  echo "Warning: curl not found, skipping" >&2
  exit 0
fi

stow_config curl
