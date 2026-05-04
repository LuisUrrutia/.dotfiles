#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin gh

stow_config gh-dash

if ! gh extension list | grep -q '^gh dash'; then
  gh extension install dlvhdr/gh-dash
else
  gh extension upgrade dlvhdr/gh-dash
fi
