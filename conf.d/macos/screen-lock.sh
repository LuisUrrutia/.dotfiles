#!/usr/bin/env bash
set -euo pipefail

case "${1:-check}" in
check | apply) action="${1:-check}" ;;
*)
  echo 'Usage: screen-lock.sh [check|apply]' >&2
  exit 2
  ;;
esac

immediate() {
  local status
  status="$(sysadminctl -screenLock status 2>&1)" || {
    printf '%s\n' "$status" >&2
    exit 1
  }
  grep -Eq 'screenLock delay is (immediate|0 seconds)[.]?$' <<<"$status"
}

if immediate; then
  exit 0
fi
if [[ "$action" == check ]]; then
  echo 'Immediate screen locking is not enabled or its status could not be read.' >&2
  exit 1
fi
if [[ ! -t 0 ]]; then
  echo 'Run ./install.sh in a terminal so macOS can authorize immediate screen locking.' >&2
  exit 1
fi

echo 'Enabling immediate screen locking. Enter your Mac login password at the macOS prompt.'
sysadminctl -screenLock immediate -password -
if ! immediate; then
  echo 'macOS did not enable immediate screen locking; setup has stopped.' >&2
  exit 1
fi
