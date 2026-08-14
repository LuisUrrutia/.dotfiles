#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

stow_config mise

# Install the global toolchain declared in config.toml. Tool-specific install
# scripts must not `mise use -g`, which would write through the stowed symlink.
(cd "$DOTFILES" && "$bin_path" install --yes)

dotfiles_root="$DOTFILES"
DOTFILES="$dotfiles_root" MISE_BIN="$bin_path" \
  /bin/bash "$dotfiles_root/tools/mise/migrate-legacy.sh"
