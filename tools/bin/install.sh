#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

mkdir -p "$HOME/.local/bin"

stale_raycast_config="$HOME/.local/bin/raycast-config"

if [[ -L "$stale_raycast_config" ]]; then
  stale_target="$(readlink "$stale_raycast_config")"
  if [[ "$stale_target" == *"tools/raycast/config/.local/bin/raycast-config" ]]; then
    rm "$stale_raycast_config"
  fi
fi

stow_config bin
