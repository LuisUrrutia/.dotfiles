#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin tmux
tmux_bin_path="$bin_path"
require_brew_bin git
git_bin_path="$bin_path"

tpm_dir="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$tpm_dir" ]]; then
  mkdir -p "$(dirname "$tpm_dir")"
  "$git_bin_path" clone https://github.com/tmux-plugins/tpm "$tpm_dir"
fi

stow_config tmux

"$tmux_bin_path" source-file "$HOME/.tmux.conf" 2>/dev/null || true
"$tpm_dir/bin/install_plugins"
