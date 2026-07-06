#!/usr/bin/env bash

# Identity env vars and EFFECTIVE_GIT_* globals set below are consumed by
# functions sourced from tools/git/common.sh, which shellcheck cannot follow.
# shellcheck disable=SC2034

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
HOME_DIR=""

# Contract required by the identity helpers in common.sh.
bin_path="git"

# shellcheck disable=SC1091
source "$ROOT_DIR/tools/git/common.sh"

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT

setup_home() {
  HOME_DIR="$TMP_ROOT/$1"
  mkdir -p "$HOME_DIR"
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

seed_config() {
  local key="$1"
  local value="$2"

  git config --file "$HOME_DIR/.gitconfig" "$key" "$value"
}

clear_identity_env() {
  unset DOTFILES_GIT_USER_NAME DOTFILES_GIT_USER_EMAIL
  unset DOTFILES_GIT_SIGNING_KEY DOTFILES_GIT_SIGNING_PROGRAM
  unset GIT_USER_NAME GIT_USER_EMAIL GIT_SIGNING_KEY GIT_SIGNING_PROGRAM
  unset DOTFILES_HAS_HARDWARE_PROFILE
  unset DOTFILES_MANAGED_GIT_IDENTITY_COUNT
  unset DOTFILES_MANAGED_GIT_USER_NAME_1 DOTFILES_MANAGED_GIT_USER_EMAIL_1
  unset DOTFILES_MANAGED_GIT_SIGNING_KEY_1 DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_1
}

test_resolve_prefers_dotfiles_vars() {
  (
    clear_identity_env
    DOTFILES_GIT_USER_NAME="Profile User"
    DOTFILES_GIT_USER_EMAIL="profile@example.com"
    DOTFILES_GIT_SIGNING_KEY="ssh-ed25519 AAAAprofile"
    DOTFILES_GIT_SIGNING_PROGRAM="/opt/profile/sign"
    GIT_USER_NAME="Fallback User"
    GIT_USER_EMAIL="fallback@example.com"
    GIT_SIGNING_KEY="ssh-ed25519 AAAAfallback"
    GIT_SIGNING_PROGRAM="/opt/fallback/sign"

    resolve_effective_git_identity

    [[ "$EFFECTIVE_GIT_USER_NAME" == "Profile User" ]]
    [[ "$EFFECTIVE_GIT_USER_EMAIL" == "profile@example.com" ]]
    [[ "$EFFECTIVE_GIT_SIGNING_KEY" == "ssh-ed25519 AAAAprofile" ]]
    [[ "$EFFECTIVE_GIT_SIGNING_PROGRAM" == "/opt/profile/sign" ]]
  )
}

test_resolve_uses_fallbacks_without_hardware_profile() {
  (
    clear_identity_env
    DOTFILES_HAS_HARDWARE_PROFILE=false
    GIT_USER_NAME="Fallback User"
    GIT_USER_EMAIL="fallback@example.com"
    GIT_SIGNING_KEY="ssh-ed25519 AAAAfallback"
    GIT_SIGNING_PROGRAM="/opt/fallback/sign"

    resolve_effective_git_identity

    [[ "$EFFECTIVE_GIT_USER_NAME" == "Fallback User" ]]
    [[ "$EFFECTIVE_GIT_USER_EMAIL" == "fallback@example.com" ]]
    [[ "$EFFECTIVE_GIT_SIGNING_KEY" == "ssh-ed25519 AAAAfallback" ]]
    [[ "$EFFECTIVE_GIT_SIGNING_PROGRAM" == "/opt/fallback/sign" ]]
  )
}

test_resolve_ignores_fallbacks_with_hardware_profile() {
  (
    clear_identity_env
    DOTFILES_HAS_HARDWARE_PROFILE=true
    GIT_USER_NAME="Fallback User"
    GIT_USER_EMAIL="fallback@example.com"
    GIT_SIGNING_KEY="ssh-ed25519 AAAAfallback"
    GIT_SIGNING_PROGRAM="/opt/fallback/sign"

    resolve_effective_git_identity

    [[ -z "$EFFECTIVE_GIT_USER_NAME" ]]
    [[ -z "$EFFECTIVE_GIT_USER_EMAIL" ]]
    [[ -z "$EFFECTIVE_GIT_SIGNING_KEY" ]]
    [[ -z "$EFFECTIVE_GIT_SIGNING_PROGRAM" ]]
  )
}

test_ensure_machine_git_config_writes_identity() {
  setup_home "ensure-writes-identity"

  (
    clear_identity_env
    HOME="$HOME_DIR"
    EFFECTIVE_GIT_USER_NAME="Example User"
    EFFECTIVE_GIT_USER_EMAIL="example@example.com"
    EFFECTIVE_GIT_SIGNING_KEY="ssh-ed25519 AAAAexample"
    EFFECTIVE_GIT_SIGNING_PROGRAM="/opt/homebrew/bin/op-ssh-sign"

    ensure_machine_git_config >/dev/null

    assert_config_value user.name "Example User"
    assert_config_value user.email "example@example.com"
    assert_config_value user.signingkey "ssh-ed25519 AAAAexample"
    assert_config_value commit.gpgsign true
    assert_config_value tag.gpgsign true
    assert_config_value tag.forcesignannotated true
    assert_config_value gpg.format ssh
    assert_config_value gpg.ssh.program /opt/homebrew/bin/op-ssh-sign
  )
}

test_ensure_machine_git_config_writes_nothing_when_empty() {
  setup_home "ensure-writes-nothing"

  (
    clear_identity_env
    HOME="$HOME_DIR"
    EFFECTIVE_GIT_USER_NAME=""
    EFFECTIVE_GIT_USER_EMAIL=""
    EFFECTIVE_GIT_SIGNING_KEY=""
    EFFECTIVE_GIT_SIGNING_PROGRAM=""

    ensure_machine_git_config >/dev/null

    [[ ! -e "$HOME_DIR/.gitconfig" ]]
  )
}

test_remove_stale_managed_identity() {
  setup_home "remove-stale-managed"
  seed_config user.name "Old User"
  seed_config user.email "old@example.com"
  seed_config user.signingkey "ssh-ed25519 AAAAold"
  seed_config commit.gpgsign true
  seed_config tag.gpgsign true
  seed_config tag.forceSignAnnotated true
  seed_config gpg.format ssh
  seed_config gpg.ssh.program /opt/old/sign

  (
    clear_identity_env
    HOME="$HOME_DIR"
    DOTFILES_MANAGED_GIT_IDENTITY_COUNT=1
    DOTFILES_MANAGED_GIT_USER_NAME_1="Old User"
    DOTFILES_MANAGED_GIT_USER_EMAIL_1="old@example.com"
    DOTFILES_MANAGED_GIT_SIGNING_KEY_1="ssh-ed25519 AAAAold"
    DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_1="/opt/old/sign"
    EFFECTIVE_GIT_USER_NAME=""
    EFFECTIVE_GIT_USER_EMAIL=""
    EFFECTIVE_GIT_SIGNING_KEY=""
    EFFECTIVE_GIT_SIGNING_PROGRAM=""

    remove_stale_managed_git_identity

    assert_config_key_absent user.name
    assert_config_key_absent user.email
    assert_config_key_absent user.signingkey
    assert_config_key_absent commit.gpgsign
    assert_config_key_absent tag.gpgsign
    assert_config_key_absent tag.forcesignannotated
    assert_config_key_absent gpg.format
    assert_config_key_absent gpg.ssh.program
  )
}

test_remove_stale_leaves_unmanaged_identity() {
  setup_home "remove-stale-unmanaged"
  seed_config user.name "Personal User"
  seed_config user.email "personal@example.com"
  seed_config user.signingkey "ssh-ed25519 AAAApersonal"
  seed_config commit.gpgsign true
  seed_config gpg.ssh.program /opt/personal/sign

  (
    clear_identity_env
    HOME="$HOME_DIR"
    DOTFILES_MANAGED_GIT_IDENTITY_COUNT=1
    DOTFILES_MANAGED_GIT_USER_NAME_1="Old User"
    DOTFILES_MANAGED_GIT_USER_EMAIL_1="old@example.com"
    DOTFILES_MANAGED_GIT_SIGNING_KEY_1="ssh-ed25519 AAAAold"
    DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_1="/opt/old/sign"
    EFFECTIVE_GIT_USER_NAME=""
    EFFECTIVE_GIT_USER_EMAIL=""
    EFFECTIVE_GIT_SIGNING_KEY=""
    EFFECTIVE_GIT_SIGNING_PROGRAM=""

    remove_stale_managed_git_identity

    assert_config_value user.name "Personal User"
    assert_config_value user.email "personal@example.com"
    assert_config_value user.signingkey "ssh-ed25519 AAAApersonal"
    assert_config_value commit.gpgsign true
    assert_config_value gpg.ssh.program /opt/personal/sign
  )
}

test_remove_stale_keeps_current_effective_identity() {
  setup_home "remove-stale-current"
  seed_config user.name "Current User"
  seed_config user.email "current@example.com"
  seed_config user.signingkey "ssh-ed25519 AAAAcurrent"
  seed_config commit.gpgsign true
  seed_config tag.gpgsign true
  seed_config tag.forceSignAnnotated true
  seed_config gpg.format ssh
  seed_config gpg.ssh.program /opt/current/sign

  (
    clear_identity_env
    HOME="$HOME_DIR"
    DOTFILES_MANAGED_GIT_IDENTITY_COUNT=1
    DOTFILES_MANAGED_GIT_USER_NAME_1="Current User"
    DOTFILES_MANAGED_GIT_USER_EMAIL_1="current@example.com"
    DOTFILES_MANAGED_GIT_SIGNING_KEY_1="ssh-ed25519 AAAAcurrent"
    DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_1="/opt/current/sign"
    EFFECTIVE_GIT_USER_NAME="Current User"
    EFFECTIVE_GIT_USER_EMAIL="current@example.com"
    EFFECTIVE_GIT_SIGNING_KEY="ssh-ed25519 AAAAcurrent"
    EFFECTIVE_GIT_SIGNING_PROGRAM="/opt/current/sign"

    remove_stale_managed_git_identity

    assert_config_value user.name "Current User"
    assert_config_value user.email "current@example.com"
    assert_config_value user.signingkey "ssh-ed25519 AAAAcurrent"
    assert_config_value commit.gpgsign true
    assert_config_value tag.gpgsign true
    assert_config_value tag.forcesignannotated true
    assert_config_value gpg.format ssh
    assert_config_value gpg.ssh.program /opt/current/sign
  )
}

tests=(
  test_resolve_prefers_dotfiles_vars
  test_resolve_uses_fallbacks_without_hardware_profile
  test_resolve_ignores_fallbacks_with_hardware_profile
  test_ensure_machine_git_config_writes_identity
  test_ensure_machine_git_config_writes_nothing_when_empty
  test_remove_stale_managed_identity
  test_remove_stale_leaves_unmanaged_identity
  test_remove_stale_keeps_current_effective_identity
)

for test_name in "${tests[@]}"; do
  "$test_name"
  printf 'ok %s\n' "$test_name"
done
