#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin btop

stow -d "$DOTFILES/tools/btop" -t "$HOME" config
