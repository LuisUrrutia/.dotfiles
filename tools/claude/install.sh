#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin claude

stow -d "$DOTFILES/tools/claude" -t "$HOME" config
