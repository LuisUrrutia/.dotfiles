#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin tldr

stow -d "$DOTFILES/tools/tlrc" -t "$HOME" config

# Update tldr pages cache
tldr --config ~/.config/tlrc/config.toml --update
