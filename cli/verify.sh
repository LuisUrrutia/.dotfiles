#!/usr/bin/env bash

run_verify() {
  case "${1:-}" in
  "")
    [[ "$#" -eq 0 ]] || verify_usage_error "accepts no arguments"
    exec /bin/bash "$DOTFILES/verification/run.sh"
    ;;
  -h | --help)
    [[ "$#" -eq 1 ]] || verify_usage_error "help accepts no arguments"
    verify_help
    return 0
    ;;
  *) verify_usage_error "unknown option: $1" ;;
  esac
}
