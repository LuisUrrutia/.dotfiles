#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin yabai

# Add yabai to sudoers
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 "$bin_path" | cut -d " " -f 1) $bin_path --load-sa" | sudo tee /private/etc/sudoers.d/yabai

# Restore yabai configuration
stow_config yabai
