#!/usr/bin/env bash

run_tool_command() {
  local command_name="${1:-}"
  local tool_name=""
  local argument=""

  # shellcheck source=tools/catalog.sh
  source "$DOTFILES/tools/catalog.sh"

  if [[ "$command_name" == list || "$command_name" == apply ]]; then
    for argument in "$@"; do
      if [[ "$argument" == -h || "$argument" == --help ]]; then
        case "$command_name" in
        apply) tool_apply_help ;;
        list) printf 'Usage: dotfiles tool list\n' ;;
        esac
        return 0
      fi
    done
  fi

  case "$command_name" in
  "" | -h | --help) tool_help ;;
  list)
    shift
    [[ "$#" -eq 0 ]] || tool_usage_error "list accepts no arguments"
    LC_ALL=C list_tools
    ;;
  apply)
    shift
    if [[ "$#" -eq 0 ]]; then
      tool_apply_help
      return 0
    fi
    [[ "$#" -eq 1 ]] || tool_usage_error "apply requires exactly one tool"
    tool_name="$1"
    if ! tool_exists "$tool_name"; then
      printf 'dotfiles tool: unknown tool: %s\n' "$tool_name" >&2
      printf "Run 'dotfiles tool list' to see available tools.\n" >&2
      return 2
    fi
    exec /bin/bash "$DOTFILES/tools/$tool_name/install.sh"
    ;;
  *) tool_usage_error "unknown command: $command_name" ;;
  esac
}
