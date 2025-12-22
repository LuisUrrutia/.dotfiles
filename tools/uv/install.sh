#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin uv
uv="$bin_path"

"$uv" python install
"$uv" tool install pre-commit --with pre-commit-uv
