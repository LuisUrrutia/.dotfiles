#!/usr/bin/env bash

set -euo pipefail

IGNORE_SCHEDULE=false
ACTIVE_PID=""
CHILD_STATUS=0
TARGET_NAMES=(
  "Homebrew"
  "mise"
  "rustup"
  "App Store"
  "Neovim"
  "Pi extensions"
  "OpenCode cache"
  "Skills"
  "Mole clean"
  "Fish plugins"
)
TARGET_OUTCOMES=()
TARGET_REASONS=()

usage() {
  printf 'Usage: dotfiles update [--ignore-schedule]\n'
}

usage_error() {
  printf 'dotfiles update: %s\n' "$1" >&2
  usage >&2
  exit 2
}

parse_args() {
  case "${1:-}" in
  "")
    [[ "$#" -eq 0 ]] || usage_error "accepts only --ignore-schedule"
    ;;
  --ignore-schedule)
    [[ "$#" -eq 1 ]] || usage_error "--ignore-schedule accepts no arguments"
    IGNORE_SCHEDULE=true
    ;;
  -h | --help)
    [[ "$#" -eq 1 ]] || usage_error "help accepts no arguments"
    usage
    exit 0
    ;;
  *)
    usage_error "unknown option: $1"
    ;;
  esac
}

set_result() {
  local index="$1"
  local outcome="$2"
  local reason="${3:-}"
  TARGET_OUTCOMES[index]="$outcome"
  TARGET_REASONS[index]="$reason"
}

interrupt() {
  local signal_name="$1"
  local exit_status="$2"

  trap - HUP INT TERM
  if [[ -n "$ACTIVE_PID" ]]; then
    kill -s "$signal_name" "$ACTIVE_PID" 2>/dev/null || true
    wait "$ACTIVE_PID" 2>/dev/null || true
  fi
  exit "$exit_status"
}

run_child() {
  "$@" &
  ACTIVE_PID="$!"
  set +e
  wait "$ACTIVE_PID"
  CHILD_STATUS=$?
  set -e
  ACTIVE_PID=""
}

run_child_quiet() {
  "$@" >/dev/null 2>&1 &
  ACTIVE_PID="$!"
  set +e
  wait "$ACTIVE_PID"
  CHILD_STATUS=$?
  set -e
  ACTIVE_PID=""
}

stamp_is_recent() {
  local stamp="$1"
  local seconds="$2"
  local modified=""
  local now=""

  [[ -f "$stamp" ]] || return 1
  modified="$(stat -f %m "$stamp")" || return 1
  now="$(date +%s)"
  ((now - modified < seconds))
}

write_stamp() {
  local stamp="$1"
  mkdir -p "$(dirname "$stamp")" && touch "$stamp"
}

update_homebrew() {
  local index=0
  local stamp="$STATE_DIR/brew"
  local step=""

  if ! command -v brew >/dev/null 2>&1; then
    set_result "$index" skipped "not found"
    return
  fi
  if [[ "$IGNORE_SCHEDULE" != true ]] && stamp_is_recent "$stamp" 86400; then
    set_result "$index" skipped "ran within the last day"
    return
  fi

  for step in update upgrade autoremove; do
    run_child brew "$step"
    if [[ "$CHILD_STATUS" -ne 0 ]]; then
      set_result "$index" failed "$step, status $CHILD_STATUS"
      return
    fi
  done

  run_child brew cleanup --prune=all
  if [[ "$CHILD_STATUS" -ne 0 ]]; then
    set_result "$index" failed "cleanup, status $CHILD_STATUS"
    return
  fi

  if ! write_stamp "$stamp"; then
    set_result "$index" failed "state stamp"
    return
  fi

  run_child brew doctor
  if [[ "$CHILD_STATUS" -ne 0 ]]; then
    set_result "$index" warning "doctor failed; maintenance completed"
  else
    set_result "$index" completed
  fi
}

update_mise() {
  local index=1
  if ! command -v mise >/dev/null 2>&1; then set_result "$index" skipped "not found"; return; fi
  run_child mise upgrade --yes
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "upgrade, status $CHILD_STATUS"; return; fi
  run_child mise prune --yes
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "prune, status $CHILD_STATUS"; return; fi
  set_result "$index" completed
}

update_rustup() {
  local index=2
  if ! command -v rustup >/dev/null 2>&1; then set_result "$index" skipped "not found"; return; fi
  run_child rustup update
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_app_store() {
  local index=3
  if ! command -v mas >/dev/null 2>&1; then set_result "$index" skipped "mas not found"; return; fi
  run_child mas upgrade
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_neovim() {
  local index=4
  if ! command -v nvim >/dev/null 2>&1; then set_result "$index" skipped "not found"; return; fi
  run_child nvim --headless "+Lazy! sync" +qa
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "plugins, status $CHILD_STATUS"; return; fi
  run_child nvim --headless "+lua if not require('config.blink').ensure() then vim.cmd.cquit() end" +qa
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "blink.cmp, status $CHILD_STATUS"; return; fi
  run_child nvim --headless "+lua require('config.treesitter').install()" +qa
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "parsers, status $CHILD_STATUS"; return; fi
  set_result "$index" completed
}

update_pi() {
  local index=5
  if ! command -v pi >/dev/null 2>&1; then set_result "$index" skipped "pi not found"; return; fi
  run_child pi update extensions
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_opencode_cache() {
  local index=6
  local cache="$HOME/.cache/opencode"
  if [[ ! -d "$cache" ]]; then set_result "$index" skipped "not present"; return; fi
  run_child /bin/rm -rf "$cache"
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_skills() {
  local index=7
  if ! command -v skills >/dev/null 2>&1; then set_result "$index" skipped "not found"; return; fi
  run_child_quiet skills list -g
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" warning "unable to list installed skills"; return; fi
  run_child skills update --yes
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_mole() {
  local index=8
  local stamp="$STATE_DIR/mole-clean"
  if ! command -v mo >/dev/null 2>&1; then set_result "$index" skipped "mo not found"; return; fi
  if [[ "$IGNORE_SCHEDULE" != true ]] && stamp_is_recent "$stamp" 604800; then
    set_result "$index" skipped "ran within the last week"
    return
  fi
  run_child mo clean
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "status $CHILD_STATUS"; return; fi
  if write_stamp "$stamp"; then set_result "$index" completed; else set_result "$index" failed "state stamp"; fi
}

update_fish_plugins() {
  local index=9
  local fish_config="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
  local manifest="$fish_config/fish_plugins"
  local fisher_file="$fish_config/functions/fisher.fish"
  local command_string=""

  if ! command -v fish >/dev/null 2>&1; then set_result "$index" skipped "Fish not found"; return; fi
  if [[ ! -f "$manifest" ]]; then set_result "$index" skipped "manifest not found"; return; fi
  if [[ ! -f "$fisher_file" ]]; then set_result "$index" skipped "Fisher not found"; return; fi

  command_string="source \"$fisher_file\"; and fisher update"
  run_child fish --no-config --command "$command_string"
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

print_summary() {
  local index=0
  local failed=false
  local reason=""

  printf '\n[update] summary\n'
  while ((index < ${#TARGET_NAMES[@]})); do
    reason="${TARGET_REASONS[$index]:-}"
    if [[ -n "$reason" ]]; then
      printf '[update] %s: %s (%s)\n' "${TARGET_NAMES[$index]}" "${TARGET_OUTCOMES[$index]}" "$reason"
    else
      printf '[update] %s: %s\n' "${TARGET_NAMES[$index]}" "${TARGET_OUTCOMES[$index]}"
    fi
    [[ "${TARGET_OUTCOMES[$index]}" == failed ]] && failed=true
    index=$((index + 1))
  done

  [[ "$failed" != true ]]
}

main() {
  parse_args "$@"
  STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/update"
  trap 'interrupt HUP 129' HUP
  trap 'interrupt INT 130' INT
  trap 'interrupt TERM 143' TERM

  update_homebrew
  update_mise
  update_rustup
  update_app_store
  update_neovim
  update_pi
  update_opencode_cache
  update_skills
  update_mole
  update_fish_plugins
  print_summary
}

main "$@"
