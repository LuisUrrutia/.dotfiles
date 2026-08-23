#!/usr/bin/env bash
# shellcheck disable=SC2034 # Parsed globals are the interface consumed by both entry points.

# Shared parser for the public Install grammar. Callers inspect the
# INSTALL_OPTION_* results and decide how to render help or errors.

reset_install_options() {
  INSTALL_OPTION_DRY_RUN=false
  INSTALL_OPTION_ALL_PROFILES=false
  INSTALL_OPTION_CORE_ONLY=false
  INSTALL_OPTION_NO_UPGRADE=false
  INSTALL_OPTION_PROFILE_LIST=""
  INSTALL_OPTION_HELP=false
  INSTALL_OPTION_ERROR=""
}

parse_install_options() {
  local argument=""
  local profile_value=""

  reset_install_options

  while (($#)); do
    argument="$1"
    shift

    case "$argument" in
    -n | --dry-run)
      INSTALL_OPTION_DRY_RUN=true
      ;;
    --all-profiles)
      INSTALL_OPTION_ALL_PROFILES=true
      ;;
    --core-only)
      INSTALL_OPTION_CORE_ONLY=true
      ;;
    --profile)
      if (($# == 0)) || [[ -z "$1" || "$1" == -* ]]; then
        INSTALL_OPTION_ERROR="--profile requires a comma-separated list"
        return 2
      fi
      profile_value="$1"
      shift
      INSTALL_OPTION_PROFILE_LIST="${INSTALL_OPTION_PROFILE_LIST:+$INSTALL_OPTION_PROFILE_LIST,}$profile_value"
      ;;
    --profile=?*)
      profile_value="${argument#--profile=}"
      if [[ "$profile_value" == -* ]]; then
        INSTALL_OPTION_ERROR="--profile requires a comma-separated list"
        return 2
      fi
      INSTALL_OPTION_PROFILE_LIST="${INSTALL_OPTION_PROFILE_LIST:+$INSTALL_OPTION_PROFILE_LIST,}$profile_value"
      ;;
    --profile=)
      INSTALL_OPTION_ERROR="--profile requires a comma-separated list"
      return 2
      ;;
    --no-upgrade)
      INSTALL_OPTION_NO_UPGRADE=true
      ;;
    -h | --help)
      INSTALL_OPTION_HELP=true
      ;;
    *)
      INSTALL_OPTION_ERROR="unknown option: $argument"
      return 2
      ;;
    esac
  done

  if [[ "$INSTALL_OPTION_CORE_ONLY" == true &&
    ("$INSTALL_OPTION_ALL_PROFILES" == true || -n "$INSTALL_OPTION_PROFILE_LIST") ]]; then
    INSTALL_OPTION_ERROR="--core-only cannot be combined with another install mode"
    return 2
  fi
  if [[ "$INSTALL_OPTION_ALL_PROFILES" == true && -n "$INSTALL_OPTION_PROFILE_LIST" ]]; then
    INSTALL_OPTION_ERROR="--all-profiles cannot be combined with --profile"
    return 2
  fi

  return 0
}
