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

prepare_machine_config() {
  local record=""
  local key=""
  local value=""
  local status=0

  if [[ -f "$machine_git_config" && ! -L "$machine_git_config" ]]; then
    cp -p "$machine_git_config" "$transaction/source"
  else
    : >"$transaction/source"
  fi
  cp -p "$transaction/source" "$transaction/filtered"
  "$GIT_BIN" config --file "$transaction/source" --null --list >"$transaction/entries"

  while IFS= read -r -d '' record; do
    key="${record%%$'\n'*}"
    value="${record#*$'\n'}"
    if [[ "$key" == include.path ]]; then
      if [[ "$value" == "$local_include_path" || "$value" == "$local_git_config" ]]; then
        has_canonical_include=true
      else
        needs_backup=true
      fi
    elif is_allowed_machine_key "$key" || is_preserved_include_if_key "$key"; then
      continue
    else
      needs_backup=true
    fi

    # Edit the copy in place: regrouping retained keys changes includeIf precedence.
    if "$GIT_BIN" config --file "$transaction/filtered" --unset-all "$key"; then
      continue
    else
      status=$?
      [[ "$status" -eq 5 ]] || return "$status"
    fi
  done <"$transaction/entries"

  [[ "$has_canonical_include" == true ]] || needs_backup=true
  cp -p "$transaction/source" "$transaction/result"
  {
    printf '[include]\n\tpath = %s\n' "$local_include_path"
    sed '/[^[:space:]]/,$!d' "$transaction/filtered"
  } >"$transaction/result"
  "$GIT_BIN" config --file "$transaction/result" --list >/dev/null
}

preflight_stow() {
  local stow_args=(--simulate --restow --no-folding)
  local filename=""

  # A split config with regular managed targets is drift, not a legacy migration.
  if [[ "$has_canonical_include" != true ]]; then
    for filename in local.gitconfig ignore; do
      if [[ -f "$git_config_dir/$filename" && ! -L "$git_config_dir/$filename" ]]; then
        stow_args+=("--ignore=^\.config/git/${filename//./\\.}$")
      fi
    done
  fi
  stow "${stow_args[@]}" -d "$DOTFILES/tools/git" -t "$HOME" config
}

backup_path() {
  local path="$1"
  backup="$path.migrated.$(/bin/date +%Y%m%d%H%M%S)"
  while [[ -e "$backup" || -L "$backup" ]]; do
    backup="$backup.$$"
  done
}

move_legacy_file() {
  local path="$1"

  [[ -f "$path" && ! -L "$path" ]] || return 0
  backup_path "$path"
  mv "$path" "$backup"
  moved_paths+=("$path")
  moved_backups+=("$backup")
  printf 'Backed up old Git file: %s\n' "$backup"
}

record_new_links() {
  local source=""
  local target=""
  local relative=""

  find "$DOTFILES/tools/git/config/" -type f -print0 >"$transaction/package-files"
  while IFS= read -r -d '' source; do
    relative="${source#"$DOTFILES/tools/git/config/"}"
    case "$relative" in
    .gitconfig | .stow-local-ignore) continue ;;
    esac
    target="$HOME/$relative"
    if [[ ! -e "$target" && ! -L "$target" ]]; then
      new_link_targets+=("$target")
      new_link_sources+=("$source")
    fi
  done <"$transaction/package-files"
}

rollback_migration() {
  local i=0
  local target=""
  local failed=false

  for ((i = 0; i < ${#new_link_targets[@]}; i++)); do
    target="${new_link_targets[$i]}"
    if [[ -L "$target" && "$target" -ef "${new_link_sources[$i]}" ]]; then
      rm "$target" || failed=true
    fi
  done
  for ((i = 0; i < ${#moved_paths[@]}; i++)); do
    target="${moved_paths[$i]}"
    if [[ -e "$target" || -L "$target" ]]; then
      printf 'Error: cannot restore over unexpected target %s; backup: %s\n' "$target" "${moved_backups[$i]}" >&2
      failed=true
    else
      mv "${moved_backups[$i]}" "$target" || failed=true
    fi
  done
  if [[ -n "$old_git_dir_link" ]]; then
    if rmdir "$git_config_dir"; then
      ln -s "$old_git_dir_link" "$git_config_dir" || failed=true
    else
      printf 'Error: could not restore Git directory link to %s\n' "$old_git_dir_link" >&2
      failed=true
    fi
  fi
  [[ "$failed" == false ]]
}

cleanup() {
  local status=$?
  trap - EXIT
  if [[ "$committed" != true ]]; then
    [[ "$status" -ne 0 ]] || status=1
    rollback_migration || status=1
  fi
  rm -rf "$transaction"
  exit "$status"
}

with_stow=false
case "${1:-}" in
"") ;;
--stow) with_stow=true ;;
*) printf 'Usage: %s [--stow]\n' "$0" >&2; exit 2 ;;
esac
[[ "$#" -le 1 ]] || exit 2

guard_machine_config_symlink
guard_git_config_dir_symlink
if [[ -e "$machine_git_config" && ! -f "$machine_git_config" ]]; then
  printf 'Error: not a regular Git config: %s\n' "$machine_git_config" >&2
  exit 1
fi

transaction="$(mktemp -d "$HOME/.git-config-migration.XXXXXX")"
committed=false
needs_backup=false
has_canonical_include=false
old_git_dir_link=""
backup=""
moved_paths=()
moved_backups=()
new_link_targets=()
new_link_sources=()
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

prepare_machine_config
if [[ "$with_stow" == true ]]; then
  # shellcheck disable=SC1091
  source "$DOTFILES/tools/lib.sh"
  preflight_stow
fi

if [[ -L "$git_config_dir" ]]; then
  old_git_dir_link="$(readlink "$git_config_dir")"
  rm "$git_config_dir"
fi
mkdir -p "$git_config_dir"
move_legacy_file "$local_git_config"
move_legacy_file "$global_git_ignore"
if [[ "$with_stow" == true ]]; then
  record_new_links
  stow_config git
fi

if [[ -f "$machine_git_config" && ! -L "$machine_git_config" && "$needs_backup" == true ]]; then
  backup_path "$machine_git_config"
  cp -p "$machine_git_config" "$backup"
  printf 'Backed up old Git machine config: %s\n' "$backup"
fi
if [[ -L "$machine_git_config" ]] || ! cmp -s "$transaction/result" "$machine_git_config"; then
  mv -f "$transaction/result" "$machine_git_config"
fi
committed=true
