#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

is_managed_machine_source() {
  local current="$1"
  local prefix=""
  local name=""

  for prefix in "$DOTFILES/machines/" "$HOME/.dotfiles/machines/"; do
    [[ "$current" == "$prefix"*.agents.md ]] || continue
    name="${current#"$prefix"}"
    name="${name%.agents.md}"
    [[ -n "$name" && "$name" != *..* && "$name" =~ ^[[:alnum:]][[:alnum:]_.-]*$ ]] &&
      return 0
  done
  return 1
}

link_is_managed() {
  local current="$1"
  local source="$2"
  local kind="$3"

  [[ "$current" == "$source" ]] && return 0

  case "$kind" in
  common)
    [[ "$current" == "$DOTFILES/tools/ai/AGENTS.md" ||
      "$current" == "$HOME/.dotfiles/tools/ai/AGENTS.md" ]]
    ;;
  codex)
    [[ "$current" == "$HOME/.agents/AGENTS.md" ]]
    ;;
  local)
    is_managed_machine_source "$current"
    ;;
  *)
    return 1
    ;;
  esac
}

destination_is_safe() {
  local source="$1"
  local target="$2"
  local kind="$3"
  local current=""

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    return 0
  fi

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    if link_is_managed "$current" "$source" "$kind"; then
      return 0
    fi
  fi

  printf 'dotfiles ai: refusing unowned instruction destination: %s\n' "$target" >&2
  return 1
}

install_link() {
  local source="$1"
  local target="$2"
  local kind="$3"
  local current=""

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    if [[ "$current" == "$source" && -e "$target" ]]; then
      return 0
    fi
    if link_is_managed "$current" "$source" "$kind"; then
      rm "$target"
    fi
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  printf 'Linked %s -> %s\n' "$target" "$source"
}

remove_stale_local_link() {
  local target="$1"
  local current=""

  [[ -L "$target" ]] || return 0
  current="$(readlink "$target")"
  if link_is_managed "$current" "" local; then
    rm "$target"
    printf 'Removed stale machine instructions: %s\n' "$target"
  fi
}

hardware_hash() {
  if [[ -n "${DOTFILES_HARDWARE_HASH_OVERRIDE:-}" ]]; then
    printf '%s\n' "$DOTFILES_HARDWARE_HASH_OVERRIDE"
    return 0
  fi

  /bin/bash "$DOTFILES/tools/bin/config/.local/bin/machash"
}

common_source="$DOTFILES/tools/ai/AGENTS.md"
common_target="$HOME/.agents/AGENTS.md"
codex_source="$common_target"
codex_target="$HOME/.codex/AGENTS.md"
local_target="$HOME/.agents/AGENTS_LOCAL.md"
machine_hash="$(hardware_hash)"
machine_config="$DOTFILES/machines/$machine_hash.sh"
local_source=""

if [[ -f "$machine_config" && -f "$DOTFILES/machines/$machine_hash.agents.md" ]]; then
  local_source="$DOTFILES/machines/$machine_hash.agents.md"
fi

destination_is_safe "$common_source" "$common_target" common || exit 1
destination_is_safe "$codex_source" "$codex_target" codex || exit 1
destination_is_safe "$local_source" "$local_target" local || exit 1

install_link "$common_source" "$common_target" common
install_link "$codex_source" "$codex_target" codex

if [[ -n "$local_source" ]]; then
  install_link "$local_source" "$local_target" local
else
  remove_stale_local_link "$local_target"
fi

if [[ -s "$HOME/.codex/AGENTS.override.md" ]]; then
  printf 'Warning: %s shadows the managed global Codex instructions.\n' \
    "$HOME/.codex/AGENTS.override.md" >&2
fi
