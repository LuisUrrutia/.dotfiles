#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fnm

eval "$("$bin_path" env --shell bash)"

# Install Node LTS if not already installed
if ! "$bin_path" list | grep -q "lts-latest"; then
  "$bin_path" install --lts
  echo "Installed Node LTS"
fi

# Set LTS as default if not already
current_default=$("$bin_path" default 2>/dev/null || true)
if [[ "$current_default" != *"lts-latest"* ]]; then
  "$bin_path" default lts-latest
  echo "Set lts-latest as default Node version"
fi

# Install pnpm via corepack if not already enabled
if ! command -v pnpm &>/dev/null; then
  corepack enable pnpm
  echo "Enabled pnpm via corepack"
fi

# Set up pnpm environment
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Install global packages if not already installed
if ! pnpm list -g agent-browser &>/dev/null; then
  pnpm install -g agent-browser
  echo "Installed agent-browser globally"
fi
