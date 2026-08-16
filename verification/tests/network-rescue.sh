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
set +e
github_api_budget_available \
  >"$TMP_DIR/rate-exhausted.out" 2>"$TMP_DIR/rate-exhausted.err"
rate_exhausted_status=$?
set -e
[[ "$rate_exhausted_status" -eq 1 ]] ||
  fail "Bootstrapper continued with an exhausted GitHub API rate limit"
grep -F '0/60' "$TMP_DIR/rate-exhausted.err" >/dev/null ||
  fail "exhausted GitHub rate limit did not report the available budget"
grep -F '1786880472' "$TMP_DIR/rate-exhausted.err" >/dev/null ||
  fail "exhausted GitHub rate limit did not report its reset"

github_api_rate_limit_response() {
  printf '%s\n' \
    '{"resources":{"core":{"limit":60,"remaining":20,"reset":1786880472}}}'
}
github_api_budget_available \
  >"$TMP_DIR/rate-available.out" 2>"$TMP_DIR/rate-available.err" ||
  fail "Bootstrapper rejected a sufficient GitHub API budget"
grep -F '20/60' "$TMP_DIR/rate-available.out" >/dev/null ||
  fail "available GitHub rate limit was not reported"

: >"$rescue_log"
github_connectivity_available() { printf '%s\n' probe >>"$rescue_log"; }
github_api_budget_available() { printf '%s\n' rate-limit >>"$rescue_log"; }
is_interactive() { return 0; }
ask_yes_no() { fail "mandatory WARP policy still asked whether to use WARP"; }
warp_app_installed() { return 1; }
warp_is_active() { return 1; }
install_warp_rescue() { printf '%s\n' install >>"$rescue_log"; }
activate_warp_rescue() { printf '%s\n' activate >>"$rescue_log"; }
ensure_bootstrap_connectivity
[[ "$(<"$rescue_log")" == $'install\nactivate\nprobe\nrate-limit' ]] ||
  fail "normal install did not validate GitHub connectivity and API budget through WARP"

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
[[ "$(<"$rescue_log")" == $'activate\nprobe\nrate-limit' ]] ||
  fail "active existing WARP installation was not reused before GitHub preflights"

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
