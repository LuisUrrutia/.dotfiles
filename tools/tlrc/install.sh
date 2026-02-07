#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin tldr

stow_config tlrc

# Update tldr pages cache
"$bin_path" --config ~/.config/tlrc/config.toml --update
