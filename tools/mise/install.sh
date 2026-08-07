#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

stow_config mise

# Install the global toolchain declared in config.toml. Tool-specific install
# scripts must not `mise use -g`, which would write through the stowed symlink.
(cd "$DOTFILES" && "$bin_path" install --yes)
