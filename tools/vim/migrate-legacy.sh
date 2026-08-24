#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

mason_bin_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin"
mason_lua_language_server="$mason_bin_dir/lua-language-server"
if [[ ! -x "$mason_lua_language_server" ]]; then
  printf 'Error: Mason did not install lua-language-server; preserving the legacy Homebrew formula.\n' >&2
  exit 1
fi

brew_bin="${HOMEBREW_PREFIX:?HOMEBREW_PREFIX is not set}/bin/brew"
if [[ ! -x "$brew_bin" ]]; then
  exit 0
fi

if "$brew_bin" list --formula lua-language-server >/dev/null 2>&1; then
  printf 'Removing legacy Homebrew formula now owned by Mason: lua-language-server\n'
  "$brew_bin" uninstall --formula lua-language-server
fi
