#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin yabai
yabai="$bin_path"

# Add yabai to sudoers
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 "$yabai" | cut -d " " -f 1) $yabai --load-sa" | sudo tee /private/etc/sudoers.d/yabai

# Restore yabai configuration
stow -d "$DOTFILES/tools/yabai" -t "$HOME" config
