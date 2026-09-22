#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app Zed

stow_config zed

set_default_app_for_extensions Zed dev.zed.Zed json yaml toml sh
