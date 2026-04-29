#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin skhd

stow_config skhd

"$bin_path" --install-service
"$bin_path" --start-service

if ! "$bin_path" --status; then
  echo "Warning: skhd service status check failed" >&2
fi

echo "If hotkeys are not functional, grant Accessibility to skhd.app and run: skhd --restart-service"
echo "Input Monitoring is only needed if you add .remap or .taphold rules."
