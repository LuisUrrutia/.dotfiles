#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app Ghostty

stow_config ghostty

"$app_path/Contents/MacOS/ghostty" +validate-config --config-file="$HOME/.config/ghostty/config.ghostty"
echo "Validated ghostty config"
