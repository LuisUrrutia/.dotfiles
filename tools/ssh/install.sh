#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
stow_config ssh
