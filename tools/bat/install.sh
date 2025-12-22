#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin bat
bat="$bin_path"

stow -d "$DOTFILES/tools/bat" -t "$HOME" config
"$bat" cache --build
