#!/usr/bin/env bash

run_install() {
  local original_count="$#"
  local -a original_args=("$@")
  local argument=""
  local core_only=false
  local all_profiles=false
  local selected_profiles=false
  local expect_profile=false
  local profile_value=""

  for argument in "$@"; do
    case "$argument" in
    -h | --help)
      install_help
      return 0
      ;;
    esac
  done

  while (($#)); do
    argument="$1"
    shift

    if [[ "$expect_profile" == true ]]; then
      [[ -n "$argument" && "$argument" != -* ]] ||
        install_usage_error "--profile requires a list"
      selected_profiles=true
      expect_profile=false
      continue
    fi

    case "$argument" in
    -n | --dry-run | --no-upgrade) ;;
    --core-only) core_only=true ;;
    --all-profiles) all_profiles=true ;;
    --profile) expect_profile=true ;;
    --profile=?*)
      profile_value="${argument#--profile=}"
      [[ "$profile_value" != -* ]] || install_usage_error "--profile requires a list"
      selected_profiles=true
      ;;
    --profile=) install_usage_error "--profile requires a list" ;;
    *) install_usage_error "unknown option: $argument" ;;
    esac
  done

  [[ "$expect_profile" != true ]] || install_usage_error "--profile requires a list"
  if [[ "$core_only" == true && ("$all_profiles" == true || "$selected_profiles" == true) ]]; then
    install_usage_error "--core-only cannot be combined with another install mode"
  fi
  if [[ "$all_profiles" == true && "$selected_profiles" == true ]]; then
    install_usage_error "--all-profiles cannot be combined with --profile"
  fi

  if [[ "$original_count" -eq 0 ]]; then
    exec /bin/bash "$DOTFILES/install.sh"
  fi
  exec /bin/bash "$DOTFILES/install.sh" "${original_args[@]}"
}
