#!/usr/bin/env bash

run_update() {
  local argument=""
  for argument in "$@"; do
    if [[ "$argument" == -h || "$argument" == --help ]] &&
      [[ "${1:-}" == --ignore-schedule || "${1:-}" == -h || "${1:-}" == --help ]]; then
      update_help
      return 0
    fi
  done

  case "${1:-}" in
  "") exec /bin/bash "$DOTFILES/maintenance/update.sh" ;;
  --ignore-schedule)
    [[ "$#" -eq 1 ]] || {
      printf 'dotfiles update: --ignore-schedule accepts no arguments\n' >&2
      update_help >&2
      return 2
    }
    exec /bin/bash "$DOTFILES/maintenance/update.sh" --ignore-schedule
    ;;
  *)
    printf 'dotfiles update: unknown option: %s\n' "$1" >&2
    update_help >&2
    return 2
    ;;
  esac
}

run_backup() {
  local target="${1:-}"
  local argument=""

  if [[ "$#" -eq 0 ]]; then
    backup_help
    return 0
  fi
  for argument in "$@"; do
    if [[ "$argument" == -h || "$argument" == --help ]]; then
      if [[ "$target" == all || "$target" == raycast || "$target" == thaw ]]; then
        backup_target_help "$target"
      elif [[ "$target" == -h || "$target" == --help ]]; then
        backup_help
      else
        printf 'dotfiles backup: unknown target: %s\n' "$target" >&2
        backup_help >&2
        return 2
      fi
      return 0
    fi
  done

  [[ "$#" -eq 1 ]] || {
    printf 'dotfiles backup: accepts exactly one target\n' >&2
    backup_help >&2
    return 2
  }
  case "$target" in
  all | raycast | thaw) exec /bin/bash "$DOTFILES/maintenance/backup.sh" "$target" ;;
  *)
    printf 'dotfiles backup: unknown target: %s\n' "$target" >&2
    backup_help >&2
    return 2
    ;;
  esac
}
