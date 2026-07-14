#!/usr/bin/env bash

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

ensure_link() {
  local source="$1"
  local target="$2"
  local current=""

  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    if [[ "$current" == "$source" ]]; then
      return 0
    fi

    if [[ -e "$target" ]]; then
      return 0
    fi

    rm "$target"
    ln -s "$source" "$target"
    echo "Repaired $target -> $source"
    return 0
  fi

  if [[ -e "$target" ]]; then
    return 0
  fi

  ln -s "$source" "$target"
  echo "Linked $target -> $source"
}

agents_source="$DOTFILES/tools/ai/AGENTS.md"

ensure_link "$agents_source" "$HOME/.agents/AGENTS.md"
