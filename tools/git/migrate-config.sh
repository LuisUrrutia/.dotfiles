#!/usr/bin/env bash

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
GIT_BIN="${GIT_BIN:-git}"

machine_git_config="$HOME/.gitconfig"
config_home="$HOME/.config"
git_config_dir="$config_home/git"
local_git_config="$git_config_dir/local.gitconfig"
local_include_path=""

# Keep this literal for Git config portability across machines.
# shellcheck disable=SC2088
printf -v local_include_path '%s' '~/.config/git/local.gitconfig'

is_old_stowed_machine_config_link() {
  local link_target="$1"

  case "$link_target" in
  "$DOTFILES"/tools/git/config/.gitconfig | */tools/git/config/.gitconfig)
    return 0
    ;;
  esac

  return 1
}

is_old_stowed_git_config_dir_link() {
  local link_target="$1"

  case "$link_target" in
  "$DOTFILES"/tools/git/config/.config/git | */tools/git/config/.config/git)
    return 0
    ;;
  esac

  return 1
}

guard_machine_config_symlink() {
  local link_target=""

  [[ -L "$machine_git_config" ]] || return 0

  link_target="$(readlink "$machine_git_config")"
  if is_old_stowed_machine_config_link "$link_target"; then
    return 0
  fi

  echo "Error: $machine_git_config is a symlink to $link_target" >&2
  echo "Move or replace that symlink manually before rerunning the Git installer." >&2
  return 1
}

guard_git_config_dir_symlink() {
  local link_target=""

  [[ -L "$git_config_dir" ]] || return 0

  link_target="$(readlink "$git_config_dir")"
  if is_old_stowed_git_config_dir_link "$link_target"; then
    return 0
  fi

  echo "Error: $git_config_dir is a symlink to $link_target" >&2
  echo "Move or replace that symlink manually before rerunning the Git installer." >&2
  return 1
}

remove_old_stowed_machine_config() {
  local link_target=""

  [[ -L "$machine_git_config" ]] || return 0

  link_target="$(readlink "$machine_git_config")"
  if is_old_stowed_machine_config_link "$link_target"; then
    rm "$machine_git_config"
  fi
}

remove_old_stowed_git_config_dir() {
  local link_target=""

  [[ -L "$git_config_dir" ]] || return 0

  link_target="$(readlink "$git_config_dir")"
  if is_old_stowed_git_config_dir_link "$link_target"; then
    rm "$git_config_dir"
  fi
}

backup_old_local_config() {
  local backup=""

  [[ -f "$local_git_config" && ! -L "$local_git_config" ]] || return 0

  backup="$local_git_config.migrated.$(/bin/date +%Y%m%d%H%M%S)"
  if [[ -e "$backup" ]]; then
    backup="$backup.$$"
  fi

  mv "$local_git_config" "$backup"
  echo "Backed up old Git config: $backup"
}

ensure_machine_config_include_first() {
  local temp_config=""

  touch "$machine_git_config"
  "$GIT_BIN" config --file "$machine_git_config" --unset-all include.path "$local_include_path" 2>/dev/null || true
  "$GIT_BIN" config --file "$machine_git_config" --unset-all include.path "$HOME/.config/git/local.gitconfig" 2>/dev/null || true

  temp_config="$(mktemp)"
  cp "$machine_git_config" "$temp_config"
  {
    printf '[include]\n'
    printf '\tpath = %s\n' "$local_include_path"
    if [[ -s "$temp_config" ]]; then
      printf '\n'
      cat "$temp_config"
    fi
  } >"$machine_git_config"
  rm -f "$temp_config"
}

mkdir -p "$config_home"
guard_machine_config_symlink
guard_git_config_dir_symlink
remove_old_stowed_machine_config
remove_old_stowed_git_config_dir
mkdir -p "$git_config_dir"
backup_old_local_config
ensure_machine_config_include_first
