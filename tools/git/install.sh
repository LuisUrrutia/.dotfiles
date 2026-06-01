#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

bin_path=""
require_brew_bin git

EFFECTIVE_GIT_USER_NAME=""
EFFECTIVE_GIT_USER_EMAIL=""
EFFECTIVE_GIT_SIGNING_KEY=""
EFFECTIVE_GIT_SIGNING_PROGRAM=""

resolve_effective_git_identity() {
  EFFECTIVE_GIT_USER_NAME="${DOTFILES_GIT_USER_NAME:-}"
  EFFECTIVE_GIT_USER_EMAIL="${DOTFILES_GIT_USER_EMAIL:-}"
  EFFECTIVE_GIT_SIGNING_KEY="${DOTFILES_GIT_SIGNING_KEY:-}"
  EFFECTIVE_GIT_SIGNING_PROGRAM="${DOTFILES_GIT_SIGNING_PROGRAM:-}"

  if [[ "${DOTFILES_HAS_HARDWARE_PROFILE:-false}" != true ]]; then
    if [[ -z "$EFFECTIVE_GIT_USER_NAME" && -n "${GIT_USER_NAME:-}" ]]; then
      EFFECTIVE_GIT_USER_NAME="$GIT_USER_NAME"
    fi

    if [[ -z "$EFFECTIVE_GIT_USER_EMAIL" && -n "${GIT_USER_EMAIL:-}" ]]; then
      EFFECTIVE_GIT_USER_EMAIL="$GIT_USER_EMAIL"
    fi

    if [[ -z "$EFFECTIVE_GIT_SIGNING_KEY" && -n "${GIT_SIGNING_KEY:-}" ]]; then
      EFFECTIVE_GIT_SIGNING_KEY="$GIT_SIGNING_KEY"
    fi

    if [[ -z "$EFFECTIVE_GIT_SIGNING_PROGRAM" && -n "${GIT_SIGNING_PROGRAM:-}" ]]; then
      EFFECTIVE_GIT_SIGNING_PROGRAM="$GIT_SIGNING_PROGRAM"
    fi
  fi
}

validate_machine_git_config_include() {
  local machine_git_config="$HOME/.gitconfig"
  local first_line=""
  local second_line=""

  IFS= read -r first_line <"$machine_git_config" || true
  second_line="$(sed -n '2p' "$machine_git_config")"

  if [[ "$first_line" != "[include]" || "$second_line" != $'\tpath = ~/.config/git/local.gitconfig' ]]; then
    echo "Error: $machine_git_config must start by including ~/.config/git/local.gitconfig" >&2
    return 1
  fi
}

ensure_machine_git_config() {
  local machine_git_config="$HOME/.gitconfig"

  if [[ -n "$EFFECTIVE_GIT_USER_NAME" ]]; then
    "$bin_path" config --file "$machine_git_config" user.name "$EFFECTIVE_GIT_USER_NAME"
  fi

  if [[ -n "$EFFECTIVE_GIT_USER_EMAIL" ]]; then
    "$bin_path" config --file "$machine_git_config" user.email "$EFFECTIVE_GIT_USER_EMAIL"
  fi

  if [[ -n "$EFFECTIVE_GIT_SIGNING_KEY" ]]; then
    "$bin_path" config --file "$machine_git_config" user.signingkey "$EFFECTIVE_GIT_SIGNING_KEY"
  fi

  if [[ -n "$EFFECTIVE_GIT_SIGNING_KEY" || -n "$EFFECTIVE_GIT_SIGNING_PROGRAM" ]]; then
    "$bin_path" config --file "$machine_git_config" commit.gpgsign true
    "$bin_path" config --file "$machine_git_config" tag.gpgsign true
    "$bin_path" config --file "$machine_git_config" tag.forceSignAnnotated true
    "$bin_path" config --file "$machine_git_config" gpg.format ssh
  fi

  if [[ -n "$EFFECTIVE_GIT_SIGNING_PROGRAM" ]]; then
    "$bin_path" config --file "$machine_git_config" gpg.ssh.program "$EFFECTIVE_GIT_SIGNING_PROGRAM"
  fi

  echo "Updated machine Git config: $machine_git_config"
}

managed_signing_program_matches() {
  local candidate="$1"
  local managed_identity_count="${DOTFILES_MANAGED_GIT_IDENTITY_COUNT:-0}"
  local i=1
  local managed_signing_program_var=""
  local managed_signing_program=""

  [[ -n "$candidate" ]] || return 1

  for ((i = 1; i <= managed_identity_count; i++)); do
    managed_signing_program_var="DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_$i"
    managed_signing_program="${!managed_signing_program_var-}"
    if [[ -n "$managed_signing_program" && "$candidate" == "$managed_signing_program" ]]; then
      return 0
    fi
  done

  return 1
}

clear_managed_signing_config() {
  local machine_git_config="$HOME/.gitconfig"
  local current_signing_program="$1"

  "$bin_path" config --file "$machine_git_config" --unset-all commit.gpgsign 2>/dev/null || true
  "$bin_path" config --file "$machine_git_config" --unset-all tag.gpgsign 2>/dev/null || true
  "$bin_path" config --file "$machine_git_config" --unset-all tag.forceSignAnnotated 2>/dev/null || true
  "$bin_path" config --file "$machine_git_config" --unset-all gpg.format 2>/dev/null || true

  if managed_signing_program_matches "$current_signing_program"; then
    "$bin_path" config --file "$machine_git_config" --unset-all gpg.ssh.program 2>/dev/null || true
  fi
}

remove_stale_managed_git_identity() {
  local machine_git_config="$HOME/.gitconfig"
  local current_name=""
  local current_email=""
  local current_signing_key=""
  local current_signing_program=""
  local managed_identity_count="${DOTFILES_MANAGED_GIT_IDENTITY_COUNT:-0}"
  local i=1
  local managed_name_var=""
  local managed_email_var=""
  local managed_signing_key_var=""
  local managed_signing_program_var=""
  local managed_name=""
  local managed_email=""
  local managed_signing_key=""
  local managed_signing_program=""
  local removed_stale_signing=false
  local stale_managed_signing_program=false

  current_name="$($bin_path config --file "$machine_git_config" --get user.name 2>/dev/null || true)"
  current_email="$($bin_path config --file "$machine_git_config" --get user.email 2>/dev/null || true)"
  current_signing_key="$($bin_path config --file "$machine_git_config" --get user.signingkey 2>/dev/null || true)"
  current_signing_program="$($bin_path config --file "$machine_git_config" --get gpg.ssh.program 2>/dev/null || true)"

  for ((i = 1; i <= managed_identity_count; i++)); do
    managed_name_var="DOTFILES_MANAGED_GIT_USER_NAME_$i"
    managed_email_var="DOTFILES_MANAGED_GIT_USER_EMAIL_$i"
    managed_signing_key_var="DOTFILES_MANAGED_GIT_SIGNING_KEY_$i"
    managed_signing_program_var="DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_$i"
    managed_name="${!managed_name_var-}"
    managed_email="${!managed_email_var-}"
    managed_signing_key="${!managed_signing_key_var-}"
    managed_signing_program="${!managed_signing_program_var-}"

    if [[ -n "$managed_name" && -n "$managed_email" && "$current_name" == "$managed_name" && "$current_email" == "$managed_email" ]]; then
      if [[ "$current_name" != "$EFFECTIVE_GIT_USER_NAME" || "$current_email" != "$EFFECTIVE_GIT_USER_EMAIL" ]]; then
        "$bin_path" config --file "$machine_git_config" --unset user.name || true
        "$bin_path" config --file "$machine_git_config" --unset user.email || true
      fi
    fi

    if [[ -n "$managed_signing_key" && "$current_signing_key" == "$managed_signing_key" ]]; then
      if [[ -z "$EFFECTIVE_GIT_SIGNING_KEY" || "$current_signing_key" != "$EFFECTIVE_GIT_SIGNING_KEY" ]]; then
        "$bin_path" config --file "$machine_git_config" --unset user.signingkey || true
        removed_stale_signing=true
      fi
    fi

    if [[ -n "$managed_signing_program" && "$current_signing_program" == "$managed_signing_program" ]]; then
      if [[ -z "$EFFECTIVE_GIT_SIGNING_PROGRAM" || "$current_signing_program" != "$EFFECTIVE_GIT_SIGNING_PROGRAM" ]]; then
        stale_managed_signing_program=true
      fi
    fi
  done

  if [[ "$removed_stale_signing" == true && -z "$EFFECTIVE_GIT_SIGNING_KEY" && -z "$EFFECTIVE_GIT_SIGNING_PROGRAM" ]]; then
    clear_managed_signing_config "$current_signing_program"
  elif [[ "$stale_managed_signing_program" == true ]]; then
    "$bin_path" config --file "$machine_git_config" --unset-all gpg.ssh.program 2>/dev/null || true
  fi
}

GIT_BIN="$bin_path" bash "$DOTFILES/tools/git/migrate-config.sh"
stow_config git
resolve_effective_git_identity
ensure_machine_git_config
remove_stale_managed_git_identity
validate_machine_git_config_include
