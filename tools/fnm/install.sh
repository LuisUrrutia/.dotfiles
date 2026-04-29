#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fnm

eval "$("$bin_path" env --use-on-cd --version-file-strategy=recursive --corepack-enabled --shell bash)"

# Install and use the latest Node LTS.
"$bin_path" install --lts --use --corepack-enabled

# Keep the latest LTS as the default Node version.
"$bin_path" default lts-latest

# Install pnpm via corepack if available from the active Node version.
if command -v corepack &>/dev/null; then
  corepack enable
  corepack prepare pnpm@latest --activate
else
  echo "Warning: corepack not found, skipping pnpm setup" >&2
  exit 0
fi

# Set up pnpm environment
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

if ! command -v pnpm &>/dev/null; then
  echo "Warning: pnpm not found, skipping global package setup" >&2
  exit 0
fi

# Install global packages if not already installed
if ! command -v agent-browser &>/dev/null; then
  pnpm install -g agent-browser
  echo "Installed agent-browser globally"
fi
