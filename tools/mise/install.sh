#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

stow_config mise

# Install the toolchain declared in config.toml (the single source of truth;
# tool-specific install scripts must not `mise use -g`, which would write
# back into the repo through the stowed symlink). Run from the repo root so
# the repo-local mise.toml (pi) also installs regardless of invocation cwd.
(cd "$DOTFILES" && "$bin_path" install --yes)
