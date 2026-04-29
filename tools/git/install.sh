#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin git

stow_config git

if [[ -L "$HOME/.local/bin" ]]; then
  rm "$HOME/.local/bin"
fi
mkdir -p "$HOME/.local/bin"
rm -f "$HOME/.local/bin/git"
install -m 0755 "$DOTFILES/tools/git/bin/git" "$HOME/.local/bin/git"
echo "Installed git wrapper"
