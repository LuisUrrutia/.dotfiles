#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$SCRIPT_DIR/.." && pwd)"
BREWFILES=()
PROFILE_SCOPE=""
WARN_ONLY=false

usage() {
  cat <<EOF
Usage: $0 [--warn-only] [--core-only | --all-profiles | --profile NAME | --file BREWFILE]

Options:
  --warn-only      Report vulnerabilities without returning a failing status
  --core-only      Scan only brewfiles/core
  --all-profiles   Scan brewfiles/core and every profile Brewfile
  --profile NAME   Scan brewfiles/core and one profile Brewfile
  --file BREWFILE  Scan brewfiles/core and an extra Brewfile
  -h, --help       Show this help

Without a profile scope, all profile Brewfiles are scanned.
EOF
}

set_fixed_profile_scope() {
  local scope="$1"

  if [[ -n "$PROFILE_SCOPE" && "$PROFILE_SCOPE" != "$scope" ]]; then
    echo "Error: profile vulnerability scope is already set to $PROFILE_SCOPE" >&2
    exit 1
  fi

  PROFILE_SCOPE="$scope"
}

set_custom_profile_scope() {
  if [[ "$PROFILE_SCOPE" == "core" || "$PROFILE_SCOPE" == "all" ]]; then
    echo "Error: profile vulnerability scope is already set to $PROFILE_SCOPE" >&2
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

  add_brewfile "$DOTFILES/brewfiles/profiles/$profile"
}

add_all_profile_brewfiles() {
  local brewfile=""

  if [[ ! -d "$DOTFILES/brewfiles/profiles" ]]; then
    return
  fi

  for brewfile in "$DOTFILES/brewfiles/profiles"/*; do
    [[ -f "$brewfile" ]] || continue
    BREWFILES+=("$brewfile")
  done
}

while (($#)); do
  case "$1" in
  --warn-only)
    WARN_ONLY=true
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
  exit 2
fi

if ! brew vulns --help >/dev/null 2>&1; then
  echo "Error: brew vulns is unavailable; install homebrew/brew-vulns/brew-vulns" >&2
  exit 2
fi

add_brewfile "$DOTFILES/brewfiles/core"
if [[ -z "$PROFILE_SCOPE" ]]; then
  add_all_profile_brewfiles
fi

vulnerabilities_found=false
scan_failed=false

for brewfile in "${BREWFILES[@]}"; do
  status=0

  printf 'Scanning Homebrew vulnerabilities in %s\n' "$brewfile"
  brew vulns --brewfile "$brewfile" --deps || status="$?"

  if [[ "$status" == 0 ]]; then
    continue
  fi

  if [[ "$status" == 1 ]]; then
    vulnerabilities_found=true
    continue
  fi

  scan_failed=true
done

if [[ "$scan_failed" == true ]]; then
  exit 2
fi

if [[ "$vulnerabilities_found" == true && "$WARN_ONLY" != true ]]; then
  exit 1
fi
