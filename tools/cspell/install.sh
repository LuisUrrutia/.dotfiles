#!/usr/bin/env bash

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

stow -d "$DOTFILES/tools/cspell" -t "$HOME" config
