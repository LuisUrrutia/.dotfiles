#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

stow_config pi

# Generate omp fish completions (gitignored; regenerated on each install)
if command -v omp >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/fish/completions"
  omp completions fish >"$HOME/.config/fish/completions/omp.fish"
fi
