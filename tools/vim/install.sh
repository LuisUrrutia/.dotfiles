#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin nvim

stow_config vim

"$bin_path" --headless "+Lazy! sync" +qa
