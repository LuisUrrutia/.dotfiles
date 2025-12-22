#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin rustup
rustup="$bin_path"

# Check if stable is already the default
current_default=$("$rustup" default 2>/dev/null | awk '{print $1}')
if [[ "$current_default" == "stable"* ]]; then
  echo "stable is already the default toolchain"
  exit 0
fi

"$rustup" default stable
echo "Set stable as the default Rust toolchain"
