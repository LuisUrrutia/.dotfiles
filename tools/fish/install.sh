#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fish
require_brew_opt fisher

stow_config fish

# Add fish to shells if not already present
grep -qxF "$bin_path" /etc/shells || sudo sh -c "echo \"$bin_path\" >> /etc/shells"

# Set fish as default shell
chsh -s "$bin_path"

# Install fish plugins
fish_plugins_path="$HOME/.config/fish/fish_plugins"
"$bin_path" --command "source \"$opt_path/share/fish/vendor_functions.d/fisher.fish\"; and test -f \"$fish_plugins_path\"; and fisher update"
