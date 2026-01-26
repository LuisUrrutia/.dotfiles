#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fish
fish="$bin_path"

stow -d "$DOTFILES/tools/fish" -t "$HOME" config

# Add fish to shells if not already present
grep -qxF "$fish" /etc/shells || sudo sh -c "echo \"$fish\" >> /etc/shells"

# Set fish as default shell
chsh -s "$fish"

# Install fish plugins
"$fish" -C "fisher update"
