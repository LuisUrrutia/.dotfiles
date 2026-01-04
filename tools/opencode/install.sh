#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

# Install OpenCode via curl because brew one is throttling it to 10 releases
curl -fsSL https://opencode.ai/install | bash

stow -d "$DOTFILES/tools/opencode" -t "$HOME" config
