#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app Ghostty

stow -d "$DOTFILES/tools/ghostty" -t "$HOME" config
