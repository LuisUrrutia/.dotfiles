#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app Hammerspoon
require_brew_bin blueutil

stow_config hammerspoon
