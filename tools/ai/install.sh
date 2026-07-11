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
skills_source="$DOTFILES/tools/ai/skills"

ensure_link "$agents_source" "$HOME/.agents/AGENTS.md"

for skill_source in "$skills_source"/*; do
  if [[ ! -f "$skill_source/SKILL.md" ]]; then
    continue
  fi

  skill_name="$(basename "$skill_source")"
  shared_skill="$HOME/.agents/skills/$skill_name"

  ensure_link "$skill_source" "$shared_skill"
  ensure_link "$shared_skill" "$HOME/.claude/skills/$skill_name"
done
