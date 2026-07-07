#!/usr/bin/env bash

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
BREWFILES_DIR="$DOTFILES/brewfiles"
PROFILE_BREWFILES_DIR="$BREWFILES_DIR/profiles"
MERGED_BREWFILE="$(mktemp)"
BREW_BUNDLE_CLEANUP_ARGS=()
BREWFILES=("$BREWFILES_DIR/core")
PROFILE_SCOPE=""

usage() {
  cat <<EOF
Usage: $0 [--force] [--core-only | --all-profiles | --profile NAME | --file BREWFILE]

Options:
  --force          Remove packages instead of only previewing cleanup
  --core-only      Keep only packages from brewfiles/core
  --all-profiles   Keep packages from brewfiles/core and every profile Brewfile
  --profile NAME   Keep packages from brewfiles/core and one profile Brewfile
  --file BREWFILE  Keep packages from brewfiles/core and an extra Brewfile
  -h, --help       Show this help

Without a profile scope, cleanup keeps all profile Brewfiles for compatibility.
EOF
}

cleanup() {
  rm -f "$MERGED_BREWFILE"
}
trap cleanup EXIT

set_fixed_profile_scope() {
  local scope="$1"

  if [[ -n "$PROFILE_SCOPE" && "$PROFILE_SCOPE" != "$scope" ]]; then
    echo "Error: profile cleanup scope is already set to $PROFILE_SCOPE" >&2
    exit 1
  fi

  PROFILE_SCOPE="$scope"
}

set_custom_profile_scope() {
  if [[ "$PROFILE_SCOPE" == "core" || "$PROFILE_SCOPE" == "all" ]]; then
    echo "Error: profile cleanup scope is already set to $PROFILE_SCOPE" >&2
    exit 1
  fi

  PROFILE_SCOPE="custom"
}

add_brewfile() {
  local brewfile="$1"

  if [[ ! -f "$brewfile" ]]; then
    echo "Error: missing Brewfile: $brewfile" >&2
    exit 1
  fi

  BREWFILES+=("$brewfile")
}

add_profile_brewfile() {
  local profile="$1"

  add_brewfile "$PROFILE_BREWFILES_DIR/$profile"
}

add_all_profile_brewfiles() {
  local brewfile=""

  if [[ ! -d "$PROFILE_BREWFILES_DIR" ]]; then
    return
  fi

  for brewfile in "$PROFILE_BREWFILES_DIR"/*; do
    [[ -f "$brewfile" ]] || continue
    BREWFILES+=("$brewfile")
  done
}

while (($#)); do
  case "$1" in
  --force)
    BREW_BUNDLE_CLEANUP_ARGS+=(--force)
    ;;
  --core-only)
    set_fixed_profile_scope core
    ;;
  --all-profiles)
    set_fixed_profile_scope all
    add_all_profile_brewfiles
    ;;
  --profile)
    shift
    if (($# == 0)); then
      echo "Error: --profile requires a profile name" >&2
      exit 1
    fi
    set_custom_profile_scope
    add_profile_brewfile "$1"
    ;;
  --profile=*)
    set_custom_profile_scope
    add_profile_brewfile "${1#--profile=}"
    ;;
  --file)
    shift
    if (($# == 0)); then
      echo "Error: --file requires a Brewfile path" >&2
      exit 1
    fi
    set_custom_profile_scope
    add_brewfile "$1"
    ;;
  --file=*)
    set_custom_profile_scope
    add_brewfile "${1#--file=}"
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Error: unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
  shift
done

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is not installed" >&2
  exit 1
fi

if [[ ! -d "$BREWFILES_DIR" ]]; then
  echo "Error: missing brewfiles directory: $BREWFILES_DIR" >&2
  exit 1
fi

if [[ -z "$PROFILE_SCOPE" ]]; then
  add_all_profile_brewfiles
fi

for brewfile in "${BREWFILES[@]}"; do
  [[ -f "$brewfile" ]] || continue
  {
    printf '# %s\n' "$brewfile"
    cat "$brewfile"
    printf '\n'
  } >>"$MERGED_BREWFILE"
done

if [[ ! -s "$MERGED_BREWFILE" ]]; then
  echo "Error: no Brewfiles found in $BREWFILES_DIR" >&2
  exit 1
fi

# The +"..." expansion keeps bash 3.2 happy when no --force flag was given;
# plain "${arr[@]}" on an empty array is an unbound-variable error there.
brew bundle cleanup --file="$MERGED_BREWFILE" ${BREW_BUNDLE_CLEANUP_ARGS[@]+"${BREW_BUNDLE_CLEANUP_ARGS[@]}"}
