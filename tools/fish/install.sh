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
"$bin_path" --command "source \"$opt_path/share/fish/vendor_functions.d/fisher.fish\"; fisher install jorgebucaran/fisher icezyclon/zoxide.fish jorgebucaran/autopair.fish patrickf1/fzf.fish"
