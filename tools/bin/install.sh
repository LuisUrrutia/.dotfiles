#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

mkdir -p "$HOME/.local/bin"

stow_config bin
