#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fish

stow_config fish

# Add fish to shells if not already present
grep -qxF "$bin_path" /etc/shells || sudo sh -c "echo \"$bin_path\" >> /etc/shells"

# Set fish as default shell
chsh -s "$bin_path"

# Install fish plugins
"$bin_path" -C "fisher update"
