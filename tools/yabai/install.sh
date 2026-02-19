#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin yabai

# Add yabai to sudoers
tmp_sudoers_file="$(mktemp)"
trap 'rm -f "$tmp_sudoers_file"' EXIT

printf '%s\n' "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 "$bin_path" | awk '{print $1}') $bin_path --load-sa" >"$tmp_sudoers_file"

sudo /usr/sbin/visudo -cf "$tmp_sudoers_file" >/dev/null
sudo /usr/bin/install -m 0440 "$tmp_sudoers_file" /private/etc/sudoers.d/yabai

# Restore yabai configuration
stow_config yabai
