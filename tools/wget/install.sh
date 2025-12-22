#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin wget

stow -d "$DOTFILES/tools/wget" -t "$HOME" config
