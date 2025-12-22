#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_opt fzf

"${opt_path}/install" --all --no-bash --no-zsh --no-fish --no-update-rc --key-bindings --completion
