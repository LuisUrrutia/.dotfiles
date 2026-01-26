#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fnm
fnm="$bin_path"

"$fnm" install --lts
"$fnm" default lts-latest
eval "$("$fnm" env --shell bash)"

# Install pnpm
corepack enable pnpm

# Install global packages
pnpm install -g agent-browser
