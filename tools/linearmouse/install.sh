#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app LinearMouse

stow -d "$DOTFILES/tools/linearmouse" -t "$HOME" config
