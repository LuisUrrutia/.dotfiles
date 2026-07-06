#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"
# shellcheck disable=SC1091
source "$DOTFILES/tools/git/common.sh"

bin_path=""
require_brew_bin git

# Globals consumed by the identity helpers sourced from common.sh.
# shellcheck disable=SC2034
EFFECTIVE_GIT_USER_NAME=""
# shellcheck disable=SC2034
EFFECTIVE_GIT_USER_EMAIL=""
# shellcheck disable=SC2034
EFFECTIVE_GIT_SIGNING_KEY=""
# shellcheck disable=SC2034
EFFECTIVE_GIT_SIGNING_PROGRAM=""

validate_machine_git_config_include() {
  local machine_git_config="$HOME/.gitconfig"

  if ! git_config_starts_with_canonical_include "$machine_git_config"; then
    echo "Error: $machine_git_config must start by including ~/.config/git/local.gitconfig" >&2
    return 1
  fi
}

GIT_BIN="$bin_path" bash "$DOTFILES/tools/git/migrate-config.sh"
stow_config git
resolve_effective_git_identity
ensure_machine_git_config
remove_stale_managed_git_identity
validate_machine_git_config_include
