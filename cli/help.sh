#!/usr/bin/env bash

root_help() {
  cat <<'EOF'
Usage: dotfiles <command> [options]

Commands:
  install       Bootstrap this Mac
  tool          List or apply Tool Installers
  verify        Run the Verification Suite
  config        Inspect or resolve Stowed Config drift
  update        Update installed software and plugins
  backup        Back up Raycast or Thaw configuration
  help          Show contextual help

Run 'dotfiles help <command>' for details.
EOF
}

install_help() {
  local profile_file=""
  local profile=""
  local summary=""

  cat <<'EOF'
Usage: dotfiles install [options]

Options:
  -n, --dry-run          Show the install plan without changing the system
      --all-profiles     Install every optional profile
      --core-only        Install only core packages
      --profile LIST     Install selected profiles (comma-separated, repeatable)
      --no-upgrade       Skip updating installed Homebrew packages
  -h, --help             Show this help
EOF

  if [[ -d "$DOTFILES/brewfiles/profiles" ]]; then
    printf '\nProfiles:\n'
    for profile_file in "$DOTFILES"/brewfiles/profiles/*; do
      [[ -f "$profile_file" ]] || continue
      profile="$(basename "$profile_file")"
      summary="$(sed -n 's/^# summary: *//p' "$profile_file" | sed -n '1p')"
      [[ -n "$summary" ]] || continue
      printf '  %-22s %s\n' "$profile" "$summary"
    done
  fi
}

install_usage_error() {
  printf 'dotfiles install: %s\n' "$1" >&2
  install_help >&2
  return 2
}

tool_help() {
  cat <<'EOF'
Usage: dotfiles tool <command>

Commands:
  list          List available Tool Installers
  apply <tool>  Run one complete Tool Installer
EOF
}

tool_apply_help() {
  cat <<'EOF'
Usage: dotfiles tool apply <tool>

Run the complete installer for one tool returned by 'dotfiles tool list'.
EOF
}

tool_usage_error() {
  printf 'dotfiles tool: %s\n' "$1" >&2
  tool_help >&2
  return 2
}

verify_help() {
  cat <<'EOF'
Usage: dotfiles verify

Run the complete offline Verification Suite.
EOF
}

verify_usage_error() {
  printf 'dotfiles verify: %s\n' "$1" >&2
  verify_help >&2
  return 2
}

config_help() {
  cat <<'EOF'
Usage: dotfiles config <command>

Commands:
  status [tool]
  diff <tool> [path]
  repair <tool> [path] [--dry-run]
  capture <tool> <path> [--dry-run]
  discard <tool> <path> [--dry-run]
  resolve <tool> <path> [--agent claude|codex]
EOF
}

config_command_help() {
  case "$1" in
  status) printf 'Usage: dotfiles config status [tool]\n' ;;
  diff) printf 'Usage: dotfiles config diff <tool> [path]\n' ;;
  repair) printf 'Usage: dotfiles config repair <tool> [path] [--dry-run]\n' ;;
  capture) printf 'Usage: dotfiles config capture <tool> <path> [--dry-run]\n' ;;
  discard) printf 'Usage: dotfiles config discard <tool> <path> [--dry-run]\n' ;;
  resolve) printf 'Usage: dotfiles config resolve <tool> <path> [--agent claude|codex]\n' ;;
  *) config_help ;;
  esac
}

config_usage_error() {
  printf 'dotfiles config: %s\n' "$1" >&2
  config_help >&2
  return 2
}

update_help() {
  cat <<'EOF'
Usage: dotfiles update [--ignore-schedule]

Update installed software and plugins. --ignore-schedule bypasses the daily
Homebrew and weekly Mole gates.
EOF
}

backup_help() {
  cat <<'EOF'
Usage: dotfiles backup <all|raycast|thaw>

Back up one application configuration or run both owners concurrently.
EOF
}

backup_target_help() {
  local target="$1"
  case "$target" in
  all | raycast | thaw) printf 'Usage: dotfiles backup %s\n' "$target" ;;
  *) backup_help ;;
  esac
}

run_help() {
  case "${1:-}" in
  "") root_help ;;
  install)
    [[ "$#" -eq 1 ]] || install_usage_error "help accepts one command path"
    install_help
    ;;
  tool)
    shift
    case "${1:-}" in
    "") tool_help ;;
    apply)
      [[ "$#" -eq 1 ]] || tool_usage_error "unknown help path"
      tool_apply_help
      ;;
    list)
      [[ "$#" -eq 1 ]] || tool_usage_error "unknown help path"
      printf 'Usage: dotfiles tool list\n'
      ;;
    *) tool_usage_error "unknown help path" ;;
    esac
    ;;
  verify)
    [[ "$#" -eq 1 ]] || verify_usage_error "unknown help path"
    verify_help
    ;;
  config)
    shift
    if [[ "$#" -eq 0 ]]; then
      config_help
    elif [[ "$#" -eq 1 && ("$1" == status || "$1" == diff || "$1" == repair ||
      "$1" == capture || "$1" == discard || "$1" == resolve) ]]; then
      config_command_help "$1"
    else
      printf 'dotfiles: unknown help path: config %s\n' "$*" >&2
      return 2
    fi
    ;;
  update)
    [[ "$#" -eq 1 ]] || {
      printf 'dotfiles: unknown help path: %s\n' "$*" >&2
      return 2
    }
    update_help
    ;;
  backup)
    shift
    if [[ "$#" -eq 0 ]]; then
      backup_help
    elif [[ "$#" -eq 1 && ("$1" == all || "$1" == raycast || "$1" == thaw) ]]; then
      backup_target_help "$1"
    else
      printf 'dotfiles: unknown help path: %s\n' "$*" >&2
      return 2
    fi
    ;;
  *)
    printf 'dotfiles: unknown help path: %s\n' "$*" >&2
    root_help >&2
    return 2
    ;;
  esac
}
