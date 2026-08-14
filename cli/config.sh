#!/usr/bin/env bash

run_config() {
  local command_name="${1:-}"
  local argument_count="$#"
  local positional=0
  local argument=""
  local accepts_dry_run=false
  local accepts_agent=false
  local -a original_args=("$@")

  if [[ "$command_name" == status || "$command_name" == diff || "$command_name" == repair ||
    "$command_name" == capture || "$command_name" == discard || "$command_name" == resolve ]]; then
    for argument in "$@"; do
      if [[ "$argument" == -h || "$argument" == --help ]]; then
        config_command_help "$command_name"
        return 0
      fi
    done
  fi

  case "$command_name" in
  "" | -h | --help)
    config_help
    return 0
    ;;
  status)
    [[ "$argument_count" -le 2 ]] || config_usage_error "status accepts at most one tool"
    [[ "${2:-}" != -* ]] || config_usage_error "unknown option: $2"
    ;;
  diff)
    [[ "$argument_count" -ge 2 && "$argument_count" -le 3 ]] ||
      config_usage_error "diff requires a tool and optional path"
    [[ "${2:-}" != -* ]] || config_usage_error "unknown option: $2"
    [[ "${3:-}" != -* ]] || config_usage_error "unknown option: $3"
    ;;
  repair | capture | discard) accepts_dry_run=true ;;
  resolve) accepts_agent=true ;;
  *) config_usage_error "unknown command: $command_name" ;;
  esac

  if [[ "$command_name" == repair || "$command_name" == capture ||
    "$command_name" == discard || "$command_name" == resolve ]]; then
    shift
    while (($#)); do
      argument="$1"
      shift
      case "$argument" in
      --dry-run)
        [[ "$accepts_dry_run" == true ]] ||
          config_usage_error "--dry-run is not valid for $command_name"
        ;;
      --agent)
        [[ "$accepts_agent" == true && "$#" -gt 0 ]] ||
          config_usage_error "--agent requires claude or codex"
        case "$1" in claude | codex) ;; *) config_usage_error "unknown agent: $1" ;; esac
        shift
        ;;
      --agent=claude | --agent=codex)
        [[ "$accepts_agent" == true ]] ||
          config_usage_error "--agent is not valid for $command_name"
        ;;
      -*) config_usage_error "unknown option: $argument" ;;
      *) positional=$((positional + 1)) ;;
      esac
    done

    case "$command_name" in
    repair)
      [[ "$positional" -ge 1 && "$positional" -le 2 ]] ||
        config_usage_error "repair requires a tool and optional path"
      ;;
    capture | discard | resolve)
      [[ "$positional" -eq 2 ]] ||
        config_usage_error "$command_name requires one tool and one path"
      ;;
    esac
  fi

  exec /bin/bash "$DOTFILES/config/run.sh" "${original_args[@]}"
}
