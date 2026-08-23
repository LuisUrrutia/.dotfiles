#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329 # Test doubles and globals feed sourced production functions.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL="$ROOT_DIR/install.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'github preflight test: %s\n' "$*" >&2
  exit 1
}

DOTFILES="$ROOT_DIR"
DOTFILES_INSTALL_NO_MAIN=true
export DOTFILES DOTFILES_INSTALL_NO_MAIN
# shellcheck disable=SC1090,SC1091
source "$INSTALL"

preflight_log="$TMP_DIR/preflight.log"
: >"$preflight_log"

github_api_rate_limit_response() {
  printf '%s\n' \
    '{"resources":{"core":{"limit":60,"remaining":0,"reset":1786880472}}}'
}
[[ "$(tmux_github_git_source_count)" -eq 4 ]] ||
  fail "Tmux Git source count does not match its declared plugins"
[[ "$(vim_github_git_source_count)" -eq 27 ]] ||
  fail "Vim Git source count does not match its declared plugins"
[[ "$(vim_treesitter_parser_source_count)" -eq 17 ]] ||
  fail "Vim parser source count does not match its declared parsers"

github_api_budget_available "Homebrew" 0 \
  >"$TMP_DIR/rate-homebrew.out" 2>"$TMP_DIR/rate-homebrew.err" ||
  fail "Homebrew was blocked by a GitHub core quota it does not consume"
grep -F 'Homebrew needs 0 core API requests' "$TMP_DIR/rate-homebrew.out" >/dev/null ||
  fail "Homebrew preflight did not explain its GitHub core API requirement"

set +e
github_api_budget_available "oversized phase" 84 \
  >"$TMP_DIR/rate-exhausted.out" 2>"$TMP_DIR/rate-exhausted.err"
rate_exhausted_status=$?
set -e
[[ "$rate_exhausted_status" -eq 1 ]] ||
  fail "Bootstrapper continued with an impossible GitHub API budget"
grep -F '0/60' "$TMP_DIR/rate-exhausted.err" >/dev/null ||
  fail "exhausted GitHub rate limit did not report the available budget"
grep -F 'oversized phase needs 84 core API requests' "$TMP_DIR/rate-exhausted.err" >/dev/null ||
  fail "exhausted GitHub rate limit did not report the impossible phase budget"
grep -F '1786880472' "$TMP_DIR/rate-exhausted.err" >/dev/null ||
  fail "exhausted GitHub rate limit did not report its reset"

rate_response_count_file="$TMP_DIR/rate-response-count"
rate_now_file="$TMP_DIR/rate-now"
printf '0\n' >"$rate_response_count_file"
printf '1000\n' >"$rate_now_file"
github_api_rate_limit_response() {
  local response_count=""

  response_count="$(<"$rate_response_count_file")"
  response_count=$((response_count + 1))
  printf '%s\n' "$response_count" >"$rate_response_count_file"
  if [[ "$response_count" -eq 1 ]]; then
    printf '%s\n' \
      '{"resources":{"core":{"limit":60,"remaining":0,"reset":1125}}}'
  else
    printf '%s\n' \
      '{"resources":{"core":{"limit":60,"remaining":59,"reset":4725}}}'
  fi
}
github_epoch_now() {
  printf '%s\n' "$(<"$rate_now_file")"
}
github_rate_limit_sleep() {
  local sleep_seconds="$1"
  local now=""

  printf '%s\n' "$sleep_seconds" >>"$TMP_DIR/rate-sleeps"
  now="$(<"$rate_now_file")"
  printf '%s\n' "$((now + sleep_seconds))" >"$rate_now_file"
}
github_api_budget_available "mise" 1 \
  >"$TMP_DIR/rate-wait.out" 2>"$TMP_DIR/rate-wait.err" ||
  fail "Bootstrapper did not resume after GitHub reset a recoverable quota"
[[ "$(<"$rate_response_count_file")" -eq 2 ]] ||
  fail "GitHub quota was not queried again after its reset"
[[ "$(<"$TMP_DIR/rate-sleeps")" == $'60\n60\n10' ]] ||
  fail "GitHub quota wait was not split into interruptible one-minute intervals"
grep -F 'Waiting until its reset' "$TMP_DIR/rate-wait.out" >/dev/null ||
  fail "recoverable GitHub quota did not explain that Bootstrapper would wait"
grep -F 'Press Ctrl-C to stop' "$TMP_DIR/rate-wait.out" >/dev/null ||
  fail "GitHub quota wait did not explain how to interrupt it"
grep -F '59/60' "$TMP_DIR/rate-wait.out" >/dev/null ||
  fail "GitHub quota was not reported after the reset"

printf '0\n' >"$rate_response_count_file"
printf '1000\n' >"$rate_now_file"
github_rate_limit_sleep() {
  return 1
}
set +e
github_api_budget_available "mise" 1 \
  >"$TMP_DIR/rate-interrupted.out" 2>"$TMP_DIR/rate-interrupted.err"
rate_interrupted_status=$?
set -e
[[ "$rate_interrupted_status" -eq 1 ]] ||
  fail "Bootstrapper ignored an interrupted GitHub quota wait"
[[ "$(<"$rate_response_count_file")" -eq 1 ]] ||
  fail "Bootstrapper queried GitHub again after its quota wait was interrupted"
grep -F 'wait was interrupted' "$TMP_DIR/rate-interrupted.err" >/dev/null ||
  fail "interrupted GitHub quota wait did not explain why Bootstrapper stopped"

github_api_rate_limit_response() {
  printf '%s\n' \
    '{"resources":{"core":{"limit":60,"remaining":59,"reset":1786880472}}}'
}
github_api_budget_available "mise" 1 \
  >"$TMP_DIR/rate-available.out" 2>"$TMP_DIR/rate-available.err" ||
  fail "Bootstrapper rejected a sufficient GitHub API budget"
grep -F '59/60' "$TMP_DIR/rate-available.out" >/dev/null ||
  fail "available GitHub rate limit was not reported"

github_api_rate_limit_response() {
  printf '%s\n' \
    '{"resources":{"core":{"limit":60,"remaining":0,"reset":1786880472}}}'
}
github_api_rate_limit_exhausted ||
  fail "exhausted GitHub core quota was not detected after an install failure"
github_api_rate_limit_response() {
  printf '%s\n' \
    '{"resources":{"core":{"limit":60,"remaining":1,"reset":1786880472}}}'
}
if github_api_rate_limit_exhausted; then
  fail "available GitHub core quota was misclassified as exhausted"
fi

: >"$preflight_log"
github_connectivity_available() { printf '%s\n' probe >>"$preflight_log"; }
github_api_budget_available() {
  printf 'budget %s %s\n' "$1" "$2" >>"$preflight_log"
}
github_phase_preflight "mise" 1 \
  "6 aqua tools and 2 github tools"
[[ "$(<"$preflight_log")" == $'probe\nbudget mise 1' ]] ||
  fail "mise preflight did not validate GitHub routes and the anonymous budget in order"

: >"$preflight_log"
# shellcheck disable=SC1091
source "$ROOT_DIR/bootstrap/github-preflight.sh"
github_connectivity_available() { return 1; }
set +e
github_phase_preflight "mise" 1 "6 aqua tools and 2 github tools" \
  >"$TMP_DIR/unreachable.out" 2>"$TMP_DIR/unreachable.err"
unreachable_status=$?
set -e
[[ "$unreachable_status" -eq 1 ]] ||
  fail "preflight continued when GitHub routes were unreachable"
grep -F 'GitHub routes are not reliable enough' "$TMP_DIR/unreachable.err" >/dev/null ||
  fail "unreachable GitHub routes did not explain why the phase stopped"

printf 'github preflight test: passed\n'
