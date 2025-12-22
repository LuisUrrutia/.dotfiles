#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin skhd

stow -d "$DOTFILES/tools/skhd" -t "$HOME" config
