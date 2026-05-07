#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

# Activate mise
eval "$("$bin_path" activate bash)"

# Install UV
"$bin_path" use -g uv@latest

stow_config python

# Install latest version of python 3
"$bin_path" use -g python@3

# Install pre-commit
uv tool install --force pre-commit --with pre-commit-uv

# Add completions
fish_completions_dir="$DOTFILES/tools/fish/config/.config/fish/completions"

mkdir -p "$fish_completions_dir"
uv generate-shell-completion fish >"$fish_completions_dir/uv.fish"
uvx --generate-shell-completion fish >"$fish_completions_dir/uvx.fish"

uv cache prune || echo "Warning: uv cache prune failed, continuing" >&2
