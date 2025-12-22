#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin git

stow -d "$DOTFILES/tools/git" -t "$HOME" config
