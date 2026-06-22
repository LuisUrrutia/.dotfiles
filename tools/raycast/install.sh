#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

if ! app_exists Raycast && ! app_exists "Raycast Beta"; then
  echo "Warning: Raycast not found, skipping" >&2
  exit 0
fi

mkdir -p "$DOTFILES/tools/raycast/backups"

stale_raycast_config="$HOME/.local/bin/raycast-config"

if [[ -L "$stale_raycast_config" ]]; then
  stale_target="$(readlink "$stale_raycast_config")"
  if [[ "$stale_target" == *"tools/bin/config/.local/bin/raycast-config" ]]; then
    rm "$stale_raycast_config"
  fi
fi

stow_config raycast

echo "Raycast config helper installed."
echo "Run 'raycast-config status' to inspect backups."
