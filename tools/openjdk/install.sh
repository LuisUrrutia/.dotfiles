#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

eval "$bin_path" activate fish | source

# Install latest lts
"$bin_path" use -g java@lts
