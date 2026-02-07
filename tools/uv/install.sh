#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin uv

"$bin_path" python install
"$bin_path" tool install pre-commit --with pre-commit-uv
