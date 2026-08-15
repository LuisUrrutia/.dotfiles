#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOTFILES="$ROOT_DIR"
DOTFILES_MACOS_NO_MAIN=true
export DOTFILES DOTFILES_MACOS_NO_MAIN

# shellcheck disable=SC1090
source "$ROOT_DIR/tools/macos/install.sh"

fail() {
  printf 'macOS install test: %s\n' "$*" >&2
  exit 1
}

DOTFILES_HARDWARE_HOSTNAME=""
run_macos_step configure_hostname 2>/dev/null
[[ "$macos_error_count" -eq 0 ]] ||
  fail "an absent optional hostname was logged as an error"
[[ "${#macos_failed_steps[@]}" -eq 0 ]] ||
  fail "an absent optional hostname was added to the failed-step summary"

DOTFILES_HARDWARE_HOSTNAME="invalid hostname"
run_macos_step configure_hostname 2>/dev/null
[[ "$macos_error_count" -gt 0 ]] ||
  fail "an invalid hostname was not reported as an actual error"
[[ "${macos_failed_steps[*]}" == *configure_hostname* ]] ||
  fail "an invalid hostname was omitted from the failed-step summary"

printf 'macOS install test: passed\n'
