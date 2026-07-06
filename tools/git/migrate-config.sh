#!/usr/bin/env bash

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
GIT_BIN="${GIT_BIN:-git}"

machine_git_config="$HOME/.gitconfig"
config_home="$HOME/.config"
git_config_dir="$config_home/git"
local_git_config="$git_config_dir/local.gitconfig"
global_git_ignore="$git_config_dir/ignore"
local_include_path=""
allowed_machine_keys=(
  user.name
  user.email
  user.signingkey
  user.useconfigonly
  commit.gpgsign
  tag.gpgsign
  tag.forcesignannotated
  gpg.format
  gpg.ssh.program
  gpg.ssh.allowedsignersfile
)

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

backup_old_git_ignore() {
  local backup=""

  [[ -f "$global_git_ignore" && ! -L "$global_git_ignore" ]] || return 0

  backup="$global_git_ignore.migrated.$(/bin/date +%Y%m%d%H%M%S)"
  if [[ -e "$backup" ]]; then
    backup="$backup.$$"
  fi

  mv "$global_git_ignore" "$backup"
  echo "Backed up old Git ignore: $backup"
}

backup_machine_config() {
  local backup=""

  [[ -f "$machine_git_config" && ! -L "$machine_git_config" ]] || return 0

  backup="$machine_git_config.migrated.$(/bin/date +%Y%m%d%H%M%S)"
  if [[ -e "$backup" ]]; then
    backup="$backup.$$"
  fi

  cp "$machine_git_config" "$backup"
  echo "Backed up old Git machine config: $backup"
}

write_include_first_config() {
  local temp_config="$1"

  {
    printf '[include]\n'
    printf '\tpath = %s\n' "$local_include_path"
    if [[ -s "$temp_config" ]]; then
      printf '\n'
      cat "$temp_config"
    fi
  } >"$machine_git_config"
}

copy_allowed_machine_keys() {
  local source_config="$1"
  local target_config="$2"
  local key=""
  local processed_include_if_keys=""
  local value=""

  for key in "${allowed_machine_keys[@]}"; do
    value="$("$GIT_BIN" config --file "$source_config" --get "$key" 2>/dev/null || true)"
    [[ -n "$value" ]] || continue

    "$GIT_BIN" config --file "$target_config" "$key" "$value"
  done

  while IFS= read -r key; do
    is_preserved_include_if_key "$key" || continue
    case "$processed_include_if_keys" in
    *$'\n'"$key"$'\n'*)
      continue
      ;;
    esac
    processed_include_if_keys+=$'\n'"$key"$'\n'

    while IFS= read -r value; do
      "$GIT_BIN" config --file "$target_config" --add "$key" "$value"
    done < <("$GIT_BIN" config --file "$source_config" --get-all "$key" 2>/dev/null || true)
  done < <("$GIT_BIN" config --file "$source_config" --name-only --list 2>/dev/null || true)
}

is_preserved_include_if_key() {
  local candidate="$1"

  [[ "$candidate" == includeif.*.path ]]
}

is_allowed_machine_key() {
  local candidate="$1"
  local key=""

  for key in "${allowed_machine_keys[@]}"; do
    if [[ "$candidate" == "$key" ]]; then
      return 0
    fi
  done

  return 1
}

machine_config_has_unmanaged_keys() {
  local key=""

  [[ -f "$machine_git_config" && ! -L "$machine_git_config" ]] || return 1

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    [[ "$key" == include.path ]] && continue
    if is_preserved_include_if_key "$key"; then
      continue
    fi
    if ! is_allowed_machine_key "$key"; then
      return 0
    fi
  done < <("$GIT_BIN" config --file "$machine_git_config" --name-only --list 2>/dev/null || true)

  return 1
}

machine_config_has_unmanaged_includes() {
  local include_path=""

  [[ -f "$machine_git_config" && ! -L "$machine_git_config" ]] || return 1

  while IFS= read -r include_path; do
    if [[ "$include_path" != "$local_include_path" && "$include_path" != "$HOME/.config/git/local.gitconfig" ]]; then
      return 0
    fi
  done < <("$GIT_BIN" config --file "$machine_git_config" --get-all include.path 2>/dev/null || true)

  return 1
}

machine_config_has_canonical_include() {
  local include_path=""

  while IFS= read -r include_path; do
    if [[ "$include_path" == "$local_include_path" || "$include_path" == "$HOME/.config/git/local.gitconfig" ]]; then
      return 0
    fi
  done < <("$GIT_BIN" config --file "$machine_git_config" --get-all include.path 2>/dev/null || true)

  return 1
}

machine_config_needs_migration_backup() {
  [[ -f "$machine_git_config" && ! -L "$machine_git_config" ]] || return 1

  if machine_config_has_unmanaged_keys; then
    return 0
  fi

  if machine_config_has_unmanaged_includes; then
    return 0
  fi

  if ! machine_config_has_canonical_include; then
    return 0
  fi

  return 1
}

rebuild_machine_config() {
  local temp_config=""
  local filtered_config=""

  touch "$machine_git_config"

  temp_config="$(mktemp)"
  filtered_config="$(mktemp)"
  cp "$machine_git_config" "$temp_config"
  copy_allowed_machine_keys "$temp_config" "$filtered_config"
  write_include_first_config "$filtered_config"
  rm -f "$temp_config" "$filtered_config"
}

ensure_machine_config_include_first() {
  if machine_config_needs_migration_backup; then
    backup_machine_config
  fi

  rebuild_machine_config
}

mkdir -p "$config_home"
guard_machine_config_symlink
guard_git_config_dir_symlink
remove_old_stowed_machine_config
remove_old_stowed_git_config_dir
mkdir -p "$git_config_dir"
backup_old_local_config
backup_old_git_ignore
ensure_machine_config_include_first
