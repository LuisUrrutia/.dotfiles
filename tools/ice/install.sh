#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app Ice

# Restore Ice menu bar settings
defaults import com.jordanbaird.Ice "$DOTFILES/tools/ice/Ice.plist"
