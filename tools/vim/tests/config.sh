#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
NVIM_CONFIG="$ROOT_DIR/tools/vim/config/.config/nvim"
TMP_DIR="$(mktemp -d)"
LAZY_DIR="$TMP_DIR/data/nvim/lazy/lazy.nvim/lua"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$LAZY_DIR" "$TMP_DIR/config"
printf '%s\n' \
  'return {' \
  '  setup = function(options)' \
  '    assert(type(options.spec) == "table")' \
  '    vim.g.dotfiles_lazy_setup = true' \
  '  end,' \
  '}' \
  >"$LAZY_DIR/lazy.lua"

XDG_DATA_HOME="$TMP_DIR/data" XDG_CONFIG_HOME="$TMP_DIR/config" \
  nvim --headless --cmd "set runtimepath^=$NVIM_CONFIG" \
  -u "$NVIM_CONFIG/init.lua" \
  "+lua assert(vim.g.dotfiles_lazy_setup == true)" +qa
