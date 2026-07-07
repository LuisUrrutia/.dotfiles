#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

# Python and uv are installed by tools/mise (declared in mise's config.toml).
eval "$("$bin_path" activate bash)"

stow_config python

# Install pre-commit
uv tool install --force pre-commit --with pre-commit-uv

# Add completions
fish_config_dir="$HOME/.config/fish"
fish_completions_dir="$fish_config_dir/completions"

if [[ -L "$fish_config_dir" ]]; then
  echo "Warning: $fish_config_dir is a symlink; run tools/fish/install.sh before generating uv Fish completions" >&2
else
  mkdir -p "$fish_completions_dir"
  uv generate-shell-completion fish >"$fish_completions_dir/uv.fish"
  uvx --generate-shell-completion fish >"$fish_completions_dir/uvx.fish"
fi

uv cache prune || echo "Warning: uv cache prune failed, continuing" >&2
