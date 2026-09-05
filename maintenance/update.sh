#!/usr/bin/env bash

set -euo pipefail

IGNORE_SCHEDULE=false
ACTIVE_PID=""
CHILD_STATUS=0
PROCESS_GROUP_PYTHON=""
TARGET_NAMES=(
  "Homebrew"
  "mise"
  "rustup"
  "App Store"
  "Neovim"
  "Skills"
  "TPack plugins"
  "tlrc pages"
  "Mole clean"
  "Fish plugins"
)
TARGET_OUTCOMES=()
TARGET_REASONS=()
TARGET_HOMEBREW=0
TARGET_MISE=1
TARGET_RUSTUP=2
TARGET_APP_STORE=3
TARGET_NEOVIM=4
TARGET_SKILLS=5
TARGET_TPACK=6
TARGET_TLRC=7
TARGET_MOLE=8
TARGET_FISH=9

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
  local active_pid="$ACTIVE_PID"

  trap - HUP INT TERM
  if [[ -n "$active_pid" ]]; then
    terminate_process_group "$signal_name" "$active_pid"
    wait "$active_pid" 2>/dev/null || true
  fi
  exit "$exit_status"
}

process_group_exists() {
  kill -0 -- "-$1" 2>/dev/null
}

terminate_process_group() {
  local signal_name="$1"
  local group_pid="$2"
  local attempt=0

  if ! kill -s "$signal_name" -- "-$group_pid" 2>/dev/null; then
    kill -s "$signal_name" "$group_pid" 2>/dev/null || true
  fi

  while process_group_exists "$group_pid" && [[ "$attempt" -lt 50 ]]; do
    /bin/sleep 0.02
    attempt=$((attempt + 1))
  done
  if process_group_exists "$group_pid"; then
    kill -KILL -- "-$group_pid" 2>/dev/null || true
  fi
}

start_child() {
  # Background jobs get /dev/null as stdin; keep the controlling TTY for sudo.
  if [[ -t 0 ]]; then
    "$PROCESS_GROUP_PYTHON" -c \
      'import os, sys; os.execvp(sys.argv[1], sys.argv[1:])' \
      "$@" </dev/tty &
  else
    "$PROCESS_GROUP_PYTHON" -c \
      'import os, sys; os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])' \
      "$@" &
  fi
  ACTIVE_PID="$!"
}

run_child() {
  local child_pid=""

  start_child "$@"
  child_pid="$ACTIVE_PID"
  set +e
  wait "$child_pid"
  CHILD_STATUS=$?
  set -e
  terminate_process_group TERM "$child_pid"
  ACTIVE_PID=""
}

run_child_quiet() {
  local child_pid=""

  start_child "$@" >/dev/null 2>&1
  child_pid="$ACTIVE_PID"
  set +e
  wait "$child_pid"
  CHILD_STATUS=$?
  set -e
  terminate_process_group TERM "$child_pid"
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
  local index="$TARGET_HOMEBREW"
  local macfuse_guard="$DOTFILES/tools/bin/config/.local/bin/macfuse-guard"
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

  run_child brew update
  if [[ "$CHILD_STATUS" -ne 0 ]]; then
    set_result "$index" failed "update, status $CHILD_STATUS"
    return
  fi

  if [[ ! -x "$macfuse_guard" ]]; then
    set_result "$index" failed "macFUSE guard not found"
    return
  fi
  run_child "$macfuse_guard" reconcile
  if [[ "$CHILD_STATUS" -ne 0 ]]; then
    set_result "$index" failed "macFUSE guard, status $CHILD_STATUS"
    return
  fi

  for step in upgrade autoremove; do
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
  local index="$TARGET_MISE"
  local completion_check="$DOTFILES/tools/fish/check-claude-completion.sh"
  if ! command -v mise >/dev/null 2>&1; then set_result "$index" skipped "not found"; return; fi
  run_child mise upgrade --yes
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "upgrade, status $CHILD_STATUS"; return; fi
  run_child mise prune --yes
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "prune, status $CHILD_STATUS"; return; fi
  if command -v claude >/dev/null 2>&1 && command -v fish >/dev/null 2>&1 && [[ -x "$completion_check" ]]; then
    run_child "$completion_check"
    if [[ "$CHILD_STATUS" -ne 0 ]]; then
      set_result "$index" warning "Claude completion drift; maintenance completed"
      return
    fi
  fi
  set_result "$index" completed
}

update_rustup() {
  local index="$TARGET_RUSTUP"
  if ! command -v rustup >/dev/null 2>&1; then set_result "$index" skipped "not found"; return; fi
  run_child rustup update
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_app_store() {
  local index="$TARGET_APP_STORE"
  if ! command -v mas >/dev/null 2>&1; then set_result "$index" skipped "mas not found"; return; fi
  run_child mas upgrade
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_neovim() {
  local index="$TARGET_NEOVIM"
  if ! command -v nvim >/dev/null 2>&1; then set_result "$index" skipped "not found"; return; fi
  run_child nvim --headless "+Lazy! sync" +qa
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "plugins, status $CHILD_STATUS"; return; fi
  run_child nvim --headless "+lua if not require('config.blink').ensure() then vim.cmd.cquit() end" +qa
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "blink.cmp, status $CHILD_STATUS"; return; fi
  run_child nvim --headless "+lua if not require('config.lsp').update() then vim.cmd.cquit() end" +qa
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "language servers, status $CHILD_STATUS"; return; fi
  run_child nvim --headless "+lua require('config.treesitter').install()" +qa
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" failed "parsers, status $CHILD_STATUS"; return; fi
  set_result "$index" completed
}

update_skills() {
  local index="$TARGET_SKILLS"
  if ! command -v skills >/dev/null 2>&1; then set_result "$index" skipped "not found"; return; fi
  run_child_quiet skills list -g
  if [[ "$CHILD_STATUS" -ne 0 ]]; then set_result "$index" warning "unable to list installed skills"; return; fi
  run_child skills update --yes
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_tpack() {
  local index="$TARGET_TPACK"
  if ! command -v tpack >/dev/null 2>&1; then set_result "$index" skipped "not found"; return; fi
  run_child tpack update all
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_tlrc() {
  local index="$TARGET_TLRC"
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/tlrc/config.toml"
  if ! command -v tldr >/dev/null 2>&1; then set_result "$index" skipped "tldr not found"; return; fi
  if [[ ! -f "$config" ]]; then set_result "$index" skipped "config not found"; return; fi
  run_child tldr --config "$config" --update
  if [[ "$CHILD_STATUS" -eq 0 ]]; then set_result "$index" completed; else set_result "$index" failed "status $CHILD_STATUS"; fi
}

update_mole() {
  local index="$TARGET_MOLE"
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
  local index="$TARGET_FISH"
  local fish_config="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
  local manifest="$fish_config/fish_plugins"
  local fisher_file="$fish_config/functions/fisher.fish"
  local fisher_prefix=""
  local command_string=""

  if ! command -v fish >/dev/null 2>&1; then set_result "$index" skipped "Fish not found"; return; fi
  if [[ ! -f "$manifest" ]]; then set_result "$index" skipped "manifest not found"; return; fi
  if [[ ! -f "$fisher_file" ]] && command -v brew >/dev/null 2>&1; then
    fisher_prefix="$(brew --prefix fisher 2>/dev/null)" || fisher_prefix=""
    if [[ -n "$fisher_prefix" ]]; then
      fisher_file="$fisher_prefix/share/fish/vendor_functions.d/fisher.fish"
    fi
  fi
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
  if ! PROCESS_GROUP_PYTHON="$(command -v python3)"; then
    printf 'dotfiles update: Python 3 is required to supervise updater process groups\n' >&2
    exit 1
  fi
  STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/update"
  trap 'interrupt HUP 129' HUP
  trap 'interrupt INT 130' INT
  trap 'interrupt TERM 143' TERM

  update_homebrew
  update_mise
  update_rustup
  update_app_store
  update_neovim
  update_skills
  update_tpack
  update_tlrc
  update_mole
  update_fish_plugins
  print_summary
}

main "$@"
