#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

stow_config mise
