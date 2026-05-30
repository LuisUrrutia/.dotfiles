#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin skhd

stow_config skhd

"$bin_path" --install-service
"$bin_path" --start-service

echo "If hotkeys are not functional, grant Accessibility to skhd and run: skhd --restart-service"
