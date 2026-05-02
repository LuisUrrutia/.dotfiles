#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin atuin

stow_config atuin
