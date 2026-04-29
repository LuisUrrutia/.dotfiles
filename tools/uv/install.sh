#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin uv

stow_config uv

fish_completions_dir="$DOTFILES/tools/fish/config/.config/fish/completions"
uvx_path="$(dirname "$bin_path")/uvx"

mkdir -p "$fish_completions_dir"

"$bin_path" python install
"$bin_path" tool install --force pre-commit --with pre-commit-uv

"$bin_path" generate-shell-completion fish >"$fish_completions_dir/uv.fish"

if [[ -x "$uvx_path" ]]; then
  "$uvx_path" --generate-shell-completion fish >"$fish_completions_dir/uvx.fish"
else
  echo "Warning: uvx not found, skipping uvx completions" >&2
fi

"$bin_path" cache prune || echo "Warning: uv cache prune failed, continuing" >&2
