#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fnm
fnm="$bin_path"

eval "$("$fnm" env --shell bash)"
"$fnm" install --lts
"$fnm" default lts-latest

# Install pnpm
corepack enable pnpm

# Set up pnpm environment
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Install global packages
pnpm install -g agent-browser
