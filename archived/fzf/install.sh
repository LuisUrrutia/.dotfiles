#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_opt fzf

"${opt_path}/install" --key-bindings --completion --no-update-rc
