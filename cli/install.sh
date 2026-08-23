#!/usr/bin/env bash

run_install() {
  local original_count="$#"
  local -a original_args=("$@")

  # shellcheck source=bootstrap/install-options.sh
  source "$DOTFILES/bootstrap/install-options.sh"

  if ! parse_install_options "$@"; then
    install_usage_error "$INSTALL_OPTION_ERROR"
  fi
  if [[ "$INSTALL_OPTION_HELP" == true ]]; then
    install_help
    return 0
  fi

  if [[ "$original_count" -eq 0 ]]; then
    exec /bin/bash "$DOTFILES/install.sh"
  fi
  exec /bin/bash "$DOTFILES/install.sh" "${original_args[@]}"
}
