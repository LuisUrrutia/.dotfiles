#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin luarocks

"$bin_path" install --server=https://luarocks.org/dev luaformatter
