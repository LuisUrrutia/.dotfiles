#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fnm
fnm="$bin_path"

"$fnm" install --lts
"$fnm" default lts-latest
"$fnm" env --use-on-cd --shell fish | source

# Install pnpm
corepack enable pnpm

# Install global packages
pnpm install -g agent-browser
