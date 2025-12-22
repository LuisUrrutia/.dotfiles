#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin tmux

stow -d "$DOTFILES/tools/tmux" -t "$HOME" config
