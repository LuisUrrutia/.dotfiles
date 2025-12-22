#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app kitty

stow -d "$DOTFILES/tools/kitty" -t "$HOME" config
