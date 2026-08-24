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

fail() {
  printf 'vim config test: %s\n' "$*" >&2
  exit 1
}

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

partial_config="$TMP_DIR/partial-config/nvim"
mkdir -p "$partial_config/lua/plugins"
ln -s "$NVIM_CONFIG/lua/plugins/lsp.lua" "$partial_config/lua/plugins/lsp.lua"

set +e
XDG_CONFIG_HOME="$TMP_DIR/partial-config" \
  nvim --headless --clean \
  --cmd "set runtimepath^=$partial_config" \
  "+lua local ok, plugins = pcall(require, 'plugins.lsp'); if not ok then vim.api.nvim_err_writeln(plugins); vim.cmd.cquit(); return end; assert(#plugins[3].opts.ensure_installed == 6)" \
  +qa >"$TMP_DIR/partial-config.out" 2>&1
partial_config_status=$?
set -e

if [[ "$partial_config_status" -ne 0 ]]; then
  cat "$TMP_DIR/partial-config.out" >&2
  fail "LSP plugin spec requires a Managed Config Entry before its first restow"
fi
