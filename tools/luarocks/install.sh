#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin luarocks
luarocks="$bin_path"

"$luarocks" install --server=https://luarocks.org/dev luaformatter
