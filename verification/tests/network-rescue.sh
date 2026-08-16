#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329 # Test doubles and globals feed sourced production functions.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL="$ROOT_DIR/install.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  if [[ -n "${NETWORK_RESCUE_TEMP_DIR:-}" ]]; then
    rm -rf "$NETWORK_RESCUE_TEMP_DIR"
  fi
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'network rescue test: %s\n' "$*" >&2
  exit 1
}

DOTFILES="$ROOT_DIR"
DOTFILES_INSTALL_NO_MAIN=true
export DOTFILES DOTFILES_INSTALL_NO_MAIN
# shellcheck disable=SC1090,SC1091
source "$INSTALL"

rescue_log="$TMP_DIR/rescue.log"
: >"$rescue_log"

NETWORK_RESCUE_MARKER="$TMP_DIR/state/network-rescue-warp"
mark_warp_rescue_managed
warp_rescue_is_managed || fail "managed rescue marker was not persisted"
rm -f "$NETWORK_RESCUE_MARKER"

at_exit() { :; }
download_warp_package() { printf '%s\n' download >>"$rescue_log"; }
warp_package_is_trusted() { printf '%s\n' package-signature >>"$rescue_log"; }
run_warp_package_installer() { printf '%s\n' installer >>"$rescue_log"; }
warp_app_installed() { printf '%s\n' app-installed >>"$rescue_log"; }
warp_app_is_trusted() { printf '%s\n' app-signature >>"$rescue_log"; }
mark_warp_rescue_managed() { printf '%s\n' marker >>"$rescue_log"; }
install_warp_rescue >"$TMP_DIR/install.out" 2>"$TMP_DIR/install.err"
[[ "$(<"$rescue_log")" == $'download\npackage-signature\ninstaller\napp-installed\napp-signature\nmarker' ]] ||
  fail "WARP rescue was not downloaded, verified, installed, and recorded in order"

# Restore the production adapter before testing its independent branches.
# shellcheck disable=SC1091
source "$ROOT_DIR/bootstrap/network-rescue.sh"

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

: >"$rescue_log"
warp_is_active() { printf '%s\n' warp >>"$rescue_log"; }
github_connectivity_available() { printf '%s\n' probe >>"$rescue_log"; }
github_api_budget_available() {
  printf 'budget %s %s\n' "$1" "$2" >>"$rescue_log"
}
github_phase_preflight "mise" 1 \
  "6 aqua tools and 2 github tools"
[[ "$(<"$rescue_log")" == $'warp\nprobe\nbudget mise 1' ]] ||
  fail "mise preflight did not validate WARP, routes, and anonymous budget in order"

# Restore the production adapter before testing WARP orchestration.
# shellcheck disable=SC1091
source "$ROOT_DIR/bootstrap/network-rescue.sh"

: >"$rescue_log"
github_connectivity_available() { printf '%s\n' probe >>"$rescue_log"; }
is_interactive() { return 0; }
ask_yes_no() { fail "mandatory WARP policy still asked whether to use WARP"; }
warp_app_installed() { return 1; }
warp_is_active() { return 1; }
install_warp_rescue() { printf '%s\n' install >>"$rescue_log"; }
activate_warp_rescue() { printf '%s\n' activate >>"$rescue_log"; }
ensure_bootstrap_connectivity
[[ "$(<"$rescue_log")" == $'install\nactivate\nprobe' ]] ||
  fail "normal install did not establish WARP and validate GitHub routes"

: >"$rescue_log"
github_connectivity_available() { fail "non-interactive install probed GitHub without WARP"; }
is_interactive() { return 1; }
warp_app_installed() { return 1; }
install_warp_rescue() { fail "non-interactive install tried to install WARP"; }
set +e
ensure_bootstrap_connectivity >"$TMP_DIR/noninteractive.out" 2>"$TMP_DIR/noninteractive.err"
noninteractive_status=$?
set -e
[[ "$noninteractive_status" -eq 1 ]] ||
  fail "non-interactive bootstrap continued without WARP"
grep -F 'WARP must be installed interactively' "$TMP_DIR/noninteractive.err" >/dev/null ||
  fail "non-interactive bootstrap did not explain the mandatory WARP requirement"

: >"$rescue_log"
github_connectivity_available() { printf '%s\n' probe >>"$rescue_log"; }
is_interactive() { return 1; }
warp_app_installed() { return 0; }
warp_app_is_trusted() { return 0; }
warp_is_active() { return 0; }
install_warp_rescue() { fail "existing WARP installation was replaced"; }
activate_warp_rescue() { printf '%s\n' activate >>"$rescue_log"; }
ensure_bootstrap_connectivity >"$TMP_DIR/existing.out" 2>"$TMP_DIR/existing.err"
[[ "$(<"$rescue_log")" == $'activate\nprobe' ]] ||
  fail "active existing WARP installation was not reused before GitHub routes"

: >"$rescue_log"
warp_is_active() { return 1; }
activate_warp_rescue() { fail "inactive WARP was opened during a non-interactive install"; }
set +e
ensure_bootstrap_connectivity >"$TMP_DIR/inactive.out" 2>"$TMP_DIR/inactive.err"
inactive_status=$?
set -e
[[ "$inactive_status" -eq 1 ]] ||
  fail "non-interactive bootstrap continued with inactive WARP"

warp_app_is_trusted() { return 1; }
activate_warp_rescue() { fail "untrusted existing WARP application was opened"; }
set +e
ensure_bootstrap_connectivity >"$TMP_DIR/untrusted-app.out" 2>"$TMP_DIR/untrusted-app.err"
untrusted_app_status=$?
set -e
[[ "$untrusted_app_status" -eq 1 ]] ||
  fail "existing WARP application with a foreign signature was accepted"

warp_app_is_trusted() { return 0; }
warp_is_active() { return 0; }
github_connectivity_available() { return 1; }
activate_warp_rescue() { :; }
set +e
ensure_bootstrap_connectivity >"$TMP_DIR/unreachable.out" 2>"$TMP_DIR/unreachable.err"
unreachable_status=$?
set -e
[[ "$unreachable_status" -eq 1 ]] ||
  fail "bootstrap continued when GitHub remained unavailable through WARP"

warp_package_signature() {
  printf '%s\n' \
    'Status: signed by a developer certificate issued by Apple for distribution' \
    'Certificate Chain:' \
    ' 1. Developer ID Installer: Cloudflare Inc. (68WVV388M8)'
}
warp_package_is_trusted "$TMP_DIR/Cloudflare_WARP.pkg" ||
  fail "current official Cloudflare package signature was rejected"

warp_package_signature() {
  printf '%s\n' 'Developer ID Installer: Example Corp (AAAAAAAAAA)'
}
set +e
warp_package_is_trusted "$TMP_DIR/Cloudflare_WARP.pkg" >/dev/null 2>&1
untrusted_status=$?
set -e
[[ "$untrusted_status" -eq 1 ]] || fail "foreign package signature was accepted"

: >"$rescue_log"
warp_rescue_is_managed() { return 0; }
uninstall_warp_rescue() { printf '%s\n' uninstall >>"$rescue_log"; }
finish_network_rescue
[[ "$(<"$rescue_log")" == uninstall ]] ||
  fail "Bootstrapper-owned WARP installation was not removed after success"

: >"$rescue_log"
warp_rescue_is_managed() { return 1; }
uninstall_warp_rescue() { fail "pre-existing WARP installation was removed"; }
finish_network_rescue
[[ ! -s "$rescue_log" ]] || fail "unmanaged WARP changed during cleanup"

printf 'network rescue test: passed\n'
