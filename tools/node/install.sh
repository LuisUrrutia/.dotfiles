#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

stow_config node

require_brew_bin mise

eval "$bin_path" activate fish | source

# Install and use the latest Node LTS.
"$bin_path" use -g node@lts

# Install bun
"$bin_path" use -g bun@latest

# Install latest version of pnpm
"$bin_path" use -g pnpm@latest

# Install agent-browser
"$bin_path" use -g aqua:vercel-labs/agent-browser

# Install markdownlint-cli2
"$bin_path" use -g markdownlint-cli2
