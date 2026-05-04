#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app Raycast

mkdir -p "$DOTFILES/tools/raycast/backups"

echo "Raycast config helper installed."
echo "Run 'raycast-config status' to inspect backups."
