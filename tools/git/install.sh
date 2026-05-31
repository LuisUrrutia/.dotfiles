#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

bin_path=""
require_brew_bin git

prepare_git_config_dir() {
  local config_home="$HOME/.config"
  local git_config_dir="$config_home/git"
  local link_target=""

  mkdir -p "$config_home"

  if [[ -L "$git_config_dir" ]]; then
    link_target="$(readlink "$git_config_dir")"
    case "$link_target" in
    "$DOTFILES"/tools/git/config/.config/git | */tools/git/config/.config/git)
      rm "$git_config_dir"
      ;;
    esac
  fi

  mkdir -p "$git_config_dir"
}

ensure_local_git_config() {
  local local_git_config="$HOME/.config/git/local.gitconfig"

  "$bin_path" config --file "$local_git_config" commit.gpgsign true
  "$bin_path" config --file "$local_git_config" tag.gpgsign true
  "$bin_path" config --file "$local_git_config" tag.forceSignAnnotated true
  "$bin_path" config --file "$local_git_config" gpg.format ssh
  "$bin_path" config --file "$local_git_config" gpg.ssh.program "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"

  if [[ -n "${GIT_USER_NAME:-}" ]]; then
    "$bin_path" config --file "$local_git_config" user.name "$GIT_USER_NAME"
  fi

  if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
    "$bin_path" config --file "$local_git_config" user.email "$GIT_USER_EMAIL"
  fi

  if [[ -n "${GIT_SIGNING_KEY:-}" ]]; then
    "$bin_path" config --file "$local_git_config" user.signingkey "$GIT_SIGNING_KEY"
  fi

  echo "Updated local Git config: $local_git_config"
}

prepare_git_config_dir
stow_config git
ensure_local_git_config
