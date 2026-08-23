#!/usr/bin/env bash

set -euo pipefail

VERIFY_GROUPS=(workflow security formats shell bootstrap lua fish brewfiles stow dispatcher)
RUN_DIR=""
ACTIVE_PIDS=()
GROUP_STATUSES=()

usage() {
  printf 'Usage: dotfiles verify\n'
}

usage_error() {
  printf 'dotfiles verify: %s\n' "$1" >&2
  usage >&2
  exit 2
}

parse_args() {
  case "${1:-}" in
  "")
    [[ "$#" -eq 0 ]] || usage_error "accepts no arguments"
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

requirements_file() {
  if [[ -n "${DOTFILES_VERIFICATION_FIXTURE:-}" ]]; then
    printf '%s/requirements\n' "$DOTFILES_VERIFICATION_FIXTURE"
  else
    printf '%s/brewfiles/verification\n' "$DOTFILES"
  fi
}

groups_dir() {
  if [[ -n "${DOTFILES_VERIFICATION_FIXTURE:-}" ]]; then
    printf '%s/groups\n' "$DOTFILES_VERIFICATION_FIXTURE"
  else
    printf '%s/verification/groups\n' "$DOTFILES"
  fi
}

read_requirements() {
  local file="$1"

  if [[ -n "${DOTFILES_VERIFICATION_FIXTURE:-}" ]]; then
    sed -e '/^[[:space:]]*$/d' -e '/^[[:space:]]*#/d' "$file"
  else
    sed -n 's/^# verify-bin:[[:space:]]*//p' "$file"
  fi
}

preflight() {
  local requirement_file=""
  local group_directory=""
  local requirement=""
  local group=""
  local missing=()

  requirement_file="$(requirements_file)"
  group_directory="$(groups_dir)"

  if [[ ! -f "$requirement_file" ]]; then
    printf 'dotfiles verify: missing Verification Toolchain declaration: %s\n' \
      "$requirement_file" >&2
    return 1
  fi

  while IFS= read -r requirement; do
    [[ -n "$requirement" ]] || continue
    command -v "$requirement" >/dev/null 2>&1 || missing+=("$requirement")
  done < <(read_requirements "$requirement_file")

  for group in "${VERIFY_GROUPS[@]}"; do
    if [[ ! -x "$group_directory/$group.sh" ]]; then
      missing+=("group:$group")
    fi
  done

  if ((${#missing[@]} > 0)); then
    printf 'dotfiles verify: missing prerequisites:\n' >&2
    for requirement in "${missing[@]}"; do
      printf '  - %s\n' "$requirement" >&2
    done
    printf 'Install them with: brew bundle install --file %s/brewfiles/verification\n' \
      "$DOTFILES" >&2
    return 1
  fi

  return 0
}

cleanup() {
  if [[ -n "$RUN_DIR" && -d "$RUN_DIR" ]]; then
    rm -rf "$RUN_DIR"
  fi
}

wait_for_process_group() {
  local group_pid="$1"
  local attempt=0

  while kill -0 -- "-$group_pid" 2>/dev/null; do
    if [[ "$attempt" -ge 250 ]]; then
      kill -KILL -- "-$group_pid" 2>/dev/null || true
      return 1
    fi
    /bin/sleep 0.02
    attempt=$((attempt + 1))
  done
}

interrupt() {
  local signal_name="$1"
  local exit_status="$2"
  local pid=""

  trap - HUP INT TERM
  for pid in "${ACTIVE_PIDS[@]}"; do
    [[ -n "$pid" ]] || continue
    kill -s "$signal_name" -- "-$pid" 2>/dev/null ||
      kill -s "$signal_name" "$pid" 2>/dev/null || true
  done
  for pid in "${ACTIVE_PIDS[@]}"; do
    [[ -n "$pid" ]] || continue
    wait "$pid" 2>/dev/null || true
  done
  for pid in "${ACTIVE_PIDS[@]}"; do
    [[ -n "$pid" ]] || continue
    wait_for_process_group "$pid" || true
  done
  cleanup
  exit "$exit_status"
}

run_offline_groups() {
  local group_directory=""
  local group_count="${#VERIFY_GROUPS[@]}"
  local batch_start=0
  local batch_end=0
  local index=0
  local group=""
  local pid=""
  local active_index=0
  local child_status=0
  local failed=false

  group_directory="$(groups_dir)"

  RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-verify.XXXXXX")"
  trap cleanup EXIT
  trap 'interrupt HUP 129' HUP
  trap 'interrupt INT 130' INT
  trap 'interrupt TERM 143' TERM

  while ((batch_start < group_count)); do
    batch_end=$((batch_start + 4))
    if ((batch_end > group_count)); then
      batch_end="$group_count"
    fi

    ACTIVE_PIDS=()
    index="$batch_start"
    while ((index < batch_end)); do
      group="${VERIFY_GROUPS[$index]}"
      python3 -c \
        'import os, sys; os.setsid(); os.execv("/bin/bash", ["/bin/bash", sys.argv[1]])' \
        "$group_directory/$group.sh" >"$RUN_DIR/$group.log" 2>&1 &
      ACTIVE_PIDS+=("$!")
      index=$((index + 1))
    done

    index="$batch_start"
    active_index=0
    while ((active_index < ${#ACTIVE_PIDS[@]})); do
      pid="${ACTIVE_PIDS[$active_index]}"
      set +e
      wait "$pid"
      child_status=$?
      set -e
      ACTIVE_PIDS[active_index]=""
      GROUP_STATUSES[index]="$child_status"
      index=$((index + 1))
      active_index=$((active_index + 1))
    done

    batch_start="$batch_end"
  done

  ACTIVE_PIDS=()

  index=0
  while ((index < group_count)); do
    group="${VERIFY_GROUPS[$index]}"
    child_status="${GROUP_STATUSES[$index]}"
    if [[ "$child_status" -eq 0 ]]; then
      printf '[verify] %s: passed\n' "$group"
    else
      cat "$RUN_DIR/$group.log"
      printf '[verify] %s: failed (status %s)\n' "$group" "$child_status"
      failed=true
    fi
    index=$((index + 1))
  done

  [[ "$failed" != true ]]
}

main() {
  parse_args "$@"
  preflight || return 1
  run_offline_groups
}

main "$@"
