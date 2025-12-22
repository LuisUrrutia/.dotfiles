#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin starship

stow -d "$DOTFILES/tools/starship" -t "$HOME" config
