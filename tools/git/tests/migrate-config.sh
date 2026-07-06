#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
MIGRATE_CONFIG="$ROOT_DIR/tools/git/migrate-config.sh"
HOME_DIR=""

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT

setup_home() {
  HOME_DIR="$TMP_ROOT/$1"
  mkdir -p "$HOME_DIR"
}

run_migration() {
  HOME="$HOME_DIR" DOTFILES="$ROOT_DIR" GIT_BIN="${GIT_BIN:-git}" bash "$MIGRATE_CONFIG" >/dev/null
}

first_include_is_canonical() {
  local first_line=""
  local second_line=""

  IFS= read -r first_line <"$HOME_DIR/.gitconfig" || true
  second_line="$(sed -n '2p' "$HOME_DIR/.gitconfig")"

  [[ "$first_line" == "[include]" ]]
  [[ "$second_line" == $'\tpath = ~/.config/git/local.gitconfig' ]]
}

config_value() {
  git config --file "$HOME_DIR/.gitconfig" --get "$1"
}

assert_config_value() {
  local key="$1"
  local expected="$2"
  local actual=""

  actual="$(config_value "$key")"
  [[ "$actual" == "$expected" ]]
}

assert_config_key_absent() {
  local key="$1"

  ! git config --file "$HOME_DIR/.gitconfig" --get "$key" >/dev/null 2>&1
}

machine_backup_count() {
  find "$HOME_DIR" -maxdepth 1 -type f -name '.gitconfig.migrated.*' 2>/dev/null | wc -l | tr -d ' '
}

local_backup_count() {
  find "$HOME_DIR/.config/git" -maxdepth 1 -type f -name 'local.gitconfig.migrated.*' 2>/dev/null | wc -l | tr -d ' '
}

ignore_backup_count() {
  find "$HOME_DIR/.config/git" -maxdepth 1 -type f -name 'ignore.migrated.*' 2>/dev/null | wc -l | tr -d ' '
}

assert_machine_backup_count() {
  [[ "$(machine_backup_count)" == "$1" ]]
}

assert_local_backup_count() {
  [[ "$(local_backup_count)" == "$1" ]]
}

assert_ignore_backup_count() {
  [[ "$(ignore_backup_count)" == "$1" ]]
}

assert_migration_fails() {
  if run_migration 2>/dev/null; then
    return 1
  fi
}

assert_no_unmanaged_machine_keys() {
  local key=""

  while IFS= read -r key; do
    case "$key" in
    include.path | user.name | user.email | user.signingkey | user.useconfigonly | commit.gpgsign | tag.gpgsign | tag.forcesignannotated | gpg.format | gpg.ssh.program | gpg.ssh.allowedsignersfile | includeif.*.path)
      ;;
    *)
      printf 'Unexpected key preserved: %s\n' "$key" >&2
      return 1
      ;;
    esac
  done < <(git config --file "$HOME_DIR/.gitconfig" --name-only --list)
}

test_monolithic_filtering() {
  setup_home "monolithic-filtering"

  cat >"$HOME_DIR/.gitconfig" <<'CONFIG'
[user]
	name = Example User
	email = example@example.com
	signingKey = ssh-ed25519 AAAAexample
	useConfigOnly = true
[gpg]
	format = ssh
[gpg "ssh"]
	program = /opt/homebrew/bin/op-ssh-sign
	allowedSignersFile = ~/.ssh/allowed_signers
[commit]
	gpgSign = true
[tag]
	gpgSign = true
	forceSignAnnotated = true
[alias]
	co = checkout
[pull]
	rebase = true
[includeIf "gitdir:~/work/"]
	path = ~/.gitconfig-work
[diff]
	tool = nvimdiff
CONFIG

  run_migration

  first_include_is_canonical
  assert_config_value user.name "Example User"
  assert_config_value user.email "example@example.com"
  assert_config_value user.signingkey "ssh-ed25519 AAAAexample"
  assert_config_value user.useconfigonly true
  assert_config_value commit.gpgsign true
  assert_config_value tag.gpgsign true
  assert_config_value tag.forcesignannotated true
  assert_config_value gpg.format ssh
  assert_config_value gpg.ssh.program /opt/homebrew/bin/op-ssh-sign
  assert_config_value gpg.ssh.allowedsignersfile "~"'/.ssh/allowed_signers'
  assert_config_key_absent alias.co
  assert_config_key_absent pull.rebase
  assert_config_value 'includeif.gitdir:~/work/.path' "~"'/.gitconfig-work'
  assert_config_key_absent diff.tool
  assert_no_unmanaged_machine_keys
  assert_machine_backup_count 1
}

test_duplicate_include_cleanup() {
  setup_home "duplicate-include-cleanup"

  cat >"$HOME_DIR/.gitconfig" <<CONFIG
[include]
	path = ~/.config/git/local.gitconfig
	path = $HOME_DIR/.config/git/local.gitconfig
	path = ~/.config/git/local.gitconfig
[user]
	name = Example User
CONFIG

  run_migration

  first_include_is_canonical
  [[ "$(git config --file "$HOME_DIR/.gitconfig" --get-all include.path | wc -l | tr -d ' ')" == "1" ]]
  assert_config_value user.name "Example User"
  assert_machine_backup_count 0
}

test_unmanaged_include_stripped_with_backup() {
  setup_home "unmanaged-include-stripped"

  cat >"$HOME_DIR/.gitconfig" <<'CONFIG'
[include]
	path = ~/.config/git/local.gitconfig
	path = ~/.config/git/delta.gitconfig
[user]
	name = Example User
CONFIG

  run_migration

  first_include_is_canonical
  # The include path is stored as a literal tilde on purpose.
  # shellcheck disable=SC2088
  [[ "$(git config --file "$HOME_DIR/.gitconfig" --get-all include.path)" == '~/.config/git/local.gitconfig' ]]
  assert_config_value user.name "Example User"
  assert_machine_backup_count 1
}

test_clean_split_config_is_idempotent() {
  setup_home "clean-split-idempotent"

  cat >"$HOME_DIR/.gitconfig" <<'CONFIG'
[include]
	path = ~/.config/git/local.gitconfig

[user]
	name = Example User
	email = example@example.com
[commit]
	gpgSign = true
CONFIG

  run_migration
  cp "$HOME_DIR/.gitconfig" "$HOME_DIR/.gitconfig.after-first"
  run_migration

  cmp "$HOME_DIR/.gitconfig.after-first" "$HOME_DIR/.gitconfig" >/dev/null
  assert_machine_backup_count 0
}

test_non_managed_machine_config_symlink_refusal() {
  setup_home "non-managed-machine-symlink"
  printf '%s\n' 'target' >"$HOME_DIR/target.gitconfig"
  ln -s "$HOME_DIR/target.gitconfig" "$HOME_DIR/.gitconfig"

  assert_migration_fails
  [[ -L "$HOME_DIR/.gitconfig" ]]
}

test_non_managed_git_config_dir_symlink_refusal() {
  setup_home "non-managed-git-dir-symlink"
  mkdir -p "$HOME_DIR/.config" "$HOME_DIR/other-git"
  ln -s "$HOME_DIR/other-git" "$HOME_DIR/.config/git"

  assert_migration_fails
  [[ -L "$HOME_DIR/.config/git" ]]
}

test_old_managed_symlink_removal() {
  setup_home "old-managed-symlink-removal"
  mkdir -p "$HOME_DIR/.config"
  ln -s "$ROOT_DIR/tools/git/config/.gitconfig" "$HOME_DIR/.gitconfig"
  ln -s "$ROOT_DIR/tools/git/config/.config/git" "$HOME_DIR/.config/git"

  run_migration

  [[ -f "$HOME_DIR/.gitconfig" ]]
  [[ ! -L "$HOME_DIR/.gitconfig" ]]
  [[ -d "$HOME_DIR/.config/git" ]]
  [[ ! -L "$HOME_DIR/.config/git" ]]
  first_include_is_canonical
}

test_local_gitconfig_backup() {
  setup_home "local-gitconfig-backup"
  mkdir -p "$HOME_DIR/.config/git"
  printf '%s\n' '[core]' '    excludesFile = ~/.gitignore_global' >"$HOME_DIR/.config/git/local.gitconfig"

  run_migration

  [[ ! -e "$HOME_DIR/.config/git/local.gitconfig" ]]
  assert_local_backup_count 1
}

test_git_ignore_backup() {
  setup_home "git-ignore-backup"
  mkdir -p "$HOME_DIR/.config/git"
  printf '%s\n' '*.local' >"$HOME_DIR/.config/git/ignore"

  run_migration

  [[ ! -e "$HOME_DIR/.config/git/ignore" ]]
  assert_ignore_backup_count 1
}

tests=(
  test_monolithic_filtering
  test_duplicate_include_cleanup
  test_unmanaged_include_stripped_with_backup
  test_clean_split_config_is_idempotent
  test_non_managed_machine_config_symlink_refusal
  test_non_managed_git_config_dir_symlink_refusal
  test_old_managed_symlink_removal
  test_local_gitconfig_backup
  test_git_ignore_backup
)

for test_name in "${tests[@]}"; do
  "$test_name"
  printf 'ok %s\n' "$test_name"
done
