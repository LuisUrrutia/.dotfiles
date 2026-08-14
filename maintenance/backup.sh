#!/usr/bin/env bash

set -euo pipefail

RUN_DIR=""
THAW_PID=""
RAYCAST_PID=""

usage() {
  printf 'Usage: dotfiles backup <all|raycast|thaw>\n'
}

cleanup() {
  [[ -z "$RUN_DIR" || ! -d "$RUN_DIR" ]] || rm -rf "$RUN_DIR"
}

interrupt() {
  local signal_name="$1"
  local exit_status="$2"
  local pid=""

  trap - HUP INT TERM
  for pid in "$THAW_PID" "$RAYCAST_PID"; do
    [[ -n "$pid" ]] || continue
    kill -s "$signal_name" "$pid" 2>/dev/null || true
  done
  for pid in "$THAW_PID" "$RAYCAST_PID"; do
    [[ -n "$pid" ]] || continue
    wait "$pid" 2>/dev/null || true
  done
  cleanup
  exit "$exit_status"
}

require_owner() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'dotfiles backup: required owner is not installed: %s\n' "$command_name" >&2
    return 1
  fi
}

read_outcome() {
  local file="$1"
  local status="$2"
  local outcome=""

  if [[ "$status" -ne 0 ]]; then
    printf 'failed\n'
    return
  fi
  if [[ -f "$file" ]]; then
    outcome="$(cat "$file")"
  fi
  case "$outcome" in
  completed | skipped) printf '%s\n' "$outcome" ;;
  *) printf 'failed\n' ;;
  esac
}

backup_all() {
  local thaw_status=0
  local raycast_status=0
  local thaw_outcome=""
  local raycast_outcome=""

  require_owner thaw-config || return 1
  require_owner raycast-config || return 1

  RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-backup.XXXXXX")"
  trap cleanup EXIT
  trap 'interrupt HUP 129' HUP
  trap 'interrupt INT 130' INT
  trap 'interrupt TERM 143' TERM

  printf '[backup] thaw: starting\n'
  DOTFILES_BACKUP_OUTCOME_FILE="$RUN_DIR/thaw.outcome" thaw-config backup &
  THAW_PID="$!"
  printf '[backup] raycast: starting\n'
  DOTFILES_BACKUP_OUTCOME_FILE="$RUN_DIR/raycast.outcome" raycast-config backup &
  RAYCAST_PID="$!"

  set +e
  wait "$THAW_PID"
  thaw_status=$?
  THAW_PID=""
  wait "$RAYCAST_PID"
  raycast_status=$?
  RAYCAST_PID=""
  set -e

  if [[ "$thaw_status" -eq 0 ]]; then
    printf '[backup] thaw: complete\n'
  else
    printf 'dotfiles backup: thaw failed with status %s\n' "$thaw_status" >&2
  fi
  if [[ "$raycast_status" -eq 0 ]]; then
    printf '[backup] raycast: complete\n'
  else
    printf 'dotfiles backup: raycast failed with status %s\n' "$raycast_status" >&2
  fi

  thaw_outcome="$(read_outcome "$RUN_DIR/thaw.outcome" "$thaw_status")"
  raycast_outcome="$(read_outcome "$RUN_DIR/raycast.outcome" "$raycast_status")"

  printf '\n[backup] summary\n'
  if [[ "$thaw_outcome" == failed ]]; then
    printf '[backup] thaw: failed (status %s)\n' "$thaw_status"
  else
    printf '[backup] thaw: %s\n' "$thaw_outcome"
  fi
  if [[ "$raycast_outcome" == failed ]]; then
    printf '[backup] raycast: failed (status %s)\n' "$raycast_status"
  else
    printf '[backup] raycast: %s\n' "$raycast_outcome"
  fi

  [[ "$thaw_outcome" != failed && "$raycast_outcome" != failed ]]
}

main() {
  local target="${1:-}"
  [[ "$#" -eq 1 ]] || {
    usage >&2
    exit 2
  }

  case "$target" in
  thaw)
    require_owner thaw-config || exit 1
    exec thaw-config backup
    ;;
  raycast)
    require_owner raycast-config || exit 1
    exec raycast-config backup
    ;;
  all)
    backup_all
    ;;
  *)
    usage >&2
    exit 2
    ;;
  esac
}

main "$@"
