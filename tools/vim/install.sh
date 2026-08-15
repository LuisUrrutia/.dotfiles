#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin nvim
nvim_bin_path="$bin_path"
require_brew_bin mise
mise_bin_path="$bin_path"

if ! tree_sitter_bin_path="$("$mise_bin_path" which tree-sitter 2>/dev/null)" ||
  [[ ! -x "$tree_sitter_bin_path" ]]; then
  echo "Error: mise-owned tree-sitter is unavailable; run dotfiles tool apply mise" >&2
  exit 1
fi
tree_sitter_bin_dir="$(dirname "$tree_sitter_bin_path")"

stow_config vim

PATH="$tree_sitter_bin_dir:$PATH" "$nvim_bin_path" --headless "+Lazy! sync" +qa
PATH="$tree_sitter_bin_dir:$PATH" \
  "$nvim_bin_path" --headless \
  "+lua if not require('config.treesitter').install() then vim.cmd.cquit() end" \
  +qa
