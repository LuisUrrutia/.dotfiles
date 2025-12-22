#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin nvim
nvim="$bin_path"

stow -d "$DOTFILES/tools/vim" -t "$HOME" config

"$nvim" --headless "+Lazy! sync" +qa
