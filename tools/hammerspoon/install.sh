#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app Hammerspoon

stow -d "$DOTFILES/tools/hammerspoon" -t "$HOME" config
