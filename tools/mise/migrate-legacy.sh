#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

mise_bin="${MISE_BIN:-}"
if [[ -z "$mise_bin" ]]; then
  require_brew_bin mise
  mise_bin="$bin_path"
fi

for command_name in claude codex tpack; do
  if ! "$mise_bin" which "$command_name" >/dev/null 2>&1; then
    printf 'Error: mise did not install the required %s command; preserving legacy Homebrew packages.\n' \
      "$command_name" >&2
    exit 1
  fi
done

if ! command -v brew >/dev/null 2>&1; then
  exit 0
fi

brew_bin="$(command -v brew)"
for legacy_cask in claude-code claude-code@latest codex tpack; do
  if "$brew_bin" list --cask "$legacy_cask" >/dev/null 2>&1; then
    printf 'Removing legacy Homebrew cask now owned by mise: %s\n' "$legacy_cask"
    "$brew_bin" uninstall --cask "$legacy_cask"
  fi
done

if "$brew_bin" list --formula tpack >/dev/null 2>&1; then
  printf 'Removing legacy Homebrew formula now owned by mise: tpack\n'
  "$brew_bin" uninstall --formula tpack
fi
