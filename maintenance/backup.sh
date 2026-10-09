#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'Usage: dotfiles backup <all|thaw>\n'
}

[[ "$#" -eq 1 ]] || {
  usage >&2
  exit 2
}

case "$1" in
all | thaw)
  if ! command -v thaw-config >/dev/null 2>&1; then
    printf 'dotfiles backup: required owner is not installed: thaw-config\n' >&2
    exit 1
  fi
  exec thaw-config backup
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
