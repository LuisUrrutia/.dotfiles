#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app Thaw

# Restore Thaw menu bar settings
defaults import com.stonerl.Thaw "$DOTFILES/tools/thaw/Thaw.plist"
