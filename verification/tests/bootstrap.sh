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
  printf 'bootstrap test: %s\n' "$*" >&2
  exit 1
}

DOTFILES="$ROOT_DIR"
DOTFILES_INSTALL_NO_MAIN=true
export DOTFILES DOTFILES_INSTALL_NO_MAIN
# shellcheck disable=SC1090,SC1091
source "$INSTALL"

[[ "$(sudo_askpass_keychain_service)" == "dotfiles.install.$$" ]] ||
  fail "SUDO_ASKPASS did not use a per-run Keychain service"

clt_request_log="$TMP_DIR/clt-request.log"
set +e
(
  has_xcode_command_line_tools() { return 1; }
  is_interactive() { return 0; }
  request_xcode_command_line_tools() { printf '%s\n' requested >>"$clt_request_log"; }
  ensure_xcode_command_line_tools
) >"$TMP_DIR/clt.out" 2>"$TMP_DIR/clt.err"
clt_status=$?
set -e
[[ "$clt_status" -eq 0 && "$(<"$clt_request_log")" == requested ]] ||
  fail "missing Command Line Tools did not start Apple's installer and stop cleanly"

set +e
(
  has_xcode_command_line_tools() { return 1; }
  is_interactive() { return 1; }
  request_xcode_command_line_tools() { return 99; }
  ensure_xcode_command_line_tools
) >"$TMP_DIR/clt-noninteractive.out" 2>"$TMP_DIR/clt-noninteractive.err"
clt_noninteractive_status=$?
set -e
[[ "$clt_noninteractive_status" -eq 1 ]] ||
  fail "non-interactive bootstrap continued without Command Line Tools"

session_log="$TMP_DIR/session.log"
check_full_disk_access() { printf '%s\n' full-disk-access >>"$session_log"; }
ensure_xcode_command_line_tools() { printf '%s\n' command-line-tools >>"$session_log"; }
start_install_caffeinate() { printf '%s\n' caffeinate >>"$session_log"; }
setup_sudo_askpass() { printf '%s\n' sudo-askpass >>"$session_log"; }
start_sudo_keepalive() { printf '%s\n' sudo-keepalive >>"$session_log"; }

prepare_install_session

cat >"$TMP_DIR/expected-session.log" <<'EOF'
full-disk-access
command-line-tools
caffeinate
sudo-askpass
sudo-keepalive
EOF
cmp -s "$TMP_DIR/expected-session.log" "$session_log" ||
  fail "early prerequisites do not run as FDA, Command Line Tools, then sudo"

orchestration_log="$TMP_DIR/orchestration.log"
(
  DOTFILES_INSTALL_NO_MAIN=true
  export DOTFILES_INSTALL_NO_MAIN
  # shellcheck disable=SC1090,SC1091
  source "$INSTALL"
  init_profile_order() { :; }
  parse_args() { DRY_RUN=false; }
  uname() { printf '%s\n' Darwin; }
  load_tool_library() { :; }
  prepare_install_session() { printf '%s\n' prerequisites >>"$orchestration_log"; }
  ensure_bootstrap_connectivity() { printf '%s\n' connectivity >>"$orchestration_log"; }
  configure_and_print_install_plan() { printf '%s\n' selection >>"$orchestration_log"; }
  load_homebrew() { :; }
  install_homebrew() { printf '%s\n' homebrew >>"$orchestration_log"; }
  install_declared_packages_and_dependents() { printf '%s\n' bundles >>"$orchestration_log"; }
  finish_network_rescue() { printf '%s\n' network-finish >>"$orchestration_log"; }
  print_next_steps() { :; }
  INSTALLED_MARKER="$TMP_DIR/installed"
  LEGACY_INSTALLED_MARKER="$TMP_DIR/legacy-installed"
  RUN_XCODE_SETUP=false
  main
)
[[ "$(<"$orchestration_log")" == $'prerequisites\nconnectivity\nselection\nhomebrew\nbundles\nnetwork-finish' ]] ||
  fail "network rescue did not wrap every networked bootstrap phase"

password_capture_count=0
password_validation_count=0
capture_sudo_password() {
  password_capture_count=$((password_capture_count + 1))
}
validate_sudo_askpass() {
  password_validation_count=$((password_validation_count + 1))
  [[ "$password_validation_count" -ge 2 ]]
}

authenticate_sudo_askpass >"$TMP_DIR/auth.out" 2>"$TMP_DIR/auth.err"
[[ "$password_capture_count" -eq 2 && "$password_validation_count" -eq 2 ]] ||
  fail "SUDO_ASKPASS did not retry one rejected password"
grep -F 'Password was not accepted. Try again.' "$TMP_DIR/auth.err" >/dev/null ||
  fail "SUDO_ASKPASS retry did not explain the rejected password"

password_capture_count=0
password_validation_count=0
validate_sudo_askpass() {
  password_validation_count=$((password_validation_count + 1))
  return 1
}
set +e
authenticate_sudo_askpass >"$TMP_DIR/auth-failed.out" 2>"$TMP_DIR/auth-failed.err"
auth_status=$?
set -e
[[ "$auth_status" -eq 1 ]] || fail "three rejected passwords did not fail bootstrap"
[[ "$password_capture_count" -eq 3 && "$password_validation_count" -eq 3 ]] ||
  fail "SUDO_ASKPASS did not stop after three rejected passwords"

BREW_BUNDLE_FAILURES=()
DOTFILES_USE_SUDO_ASKPASS=true
credential_valid=true
brew_attempt_count=0
password_capture_count=0
password_validation_count=0
ensure_bootstrap_connectivity() { :; }
brew_bundle_retry_delay() { :; }
brew() {
  brew_attempt_count=$((brew_attempt_count + 1))
  if [[ "$brew_attempt_count" -eq 1 ]]; then
    credential_valid=false
    return 1
  fi
  [[ "$credential_valid" == true ]]
}
validate_sudo_askpass() {
  password_validation_count=$((password_validation_count + 1))
  [[ "$credential_valid" == true ]]
}
authenticate_sudo_askpass() {
  password_capture_count=$((password_capture_count + 1))
  credential_valid=true
}
run_brew_bundle_install "askpass fixture" "$TMP_DIR/Brewfile" \
  >"$TMP_DIR/brew-askpass.out" 2>"$TMP_DIR/brew-askpass.err"
[[ "${#BREW_BUNDLE_FAILURES[@]}" -eq 0 && "$password_capture_count" -eq 1 ]] ||
  fail "Brew Bundle retry did not recover an unavailable SUDO_ASKPASS credential"

BREW_BUNDLE_FAILURES=()
DOTFILES_USE_SUDO_ASKPASS=false
unset HOMEBREW_CURL_RETRIES HOMEBREW_DOWNLOAD_CONCURRENCY
brew_attempt_count=0
brew_jobs_log="$TMP_DIR/brew-jobs.log"
brew_env_log="$TMP_DIR/brew-env.log"
brew_bundle_retry_delay() { :; }
brew() {
  brew_attempt_count=$((brew_attempt_count + 1))
  printf '%s\n' "$*" >>"$brew_jobs_log"
  printf '%s|%s\n' "$HOMEBREW_CURL_RETRIES" "$HOMEBREW_DOWNLOAD_CONCURRENCY" >>"$brew_env_log"
  [[ "$brew_attempt_count" -ge 2 ]]
}

run_brew_bundle_install "core packages" "$TMP_DIR/Brewfile" \
  >"$TMP_DIR/brew-retry.out" 2>"$TMP_DIR/brew-retry.err"
[[ "$brew_attempt_count" -eq 2 ]] || fail "transient Brew Bundle failure was not retried"
[[ "${#BREW_BUNDLE_FAILURES[@]}" -eq 0 ]] ||
  fail "successful Brew Bundle retry remained marked failed"
[[ "$(<"$brew_env_log")" == $'5|auto\n5|auto' ]] ||
  fail "parallel Brew Bundle attempts did not strengthen Homebrew download retries"
[[ "$(<"$brew_jobs_log")" == $'bundle install --jobs=auto --file '"$TMP_DIR"$'/Brewfile\nbundle install --jobs=auto --file '"$TMP_DIR"'/Brewfile' ]] ||
  fail "transient Brew Bundle retry did not preserve parallel jobs"

BREW_BUNDLE_FAILURES=()
brew_attempt_count=0
: >"$brew_jobs_log"
: >"$brew_env_log"
brew() {
  brew_attempt_count=$((brew_attempt_count + 1))
  printf '%s\n' "$*" >>"$brew_jobs_log"
  printf '%s|%s\n' "$HOMEBREW_CURL_RETRIES" "$HOMEBREW_DOWNLOAD_CONCURRENCY" >>"$brew_env_log"
  return 1
}
run_brew_bundle_install "core packages" "$TMP_DIR/Brewfile" \
  >"$TMP_DIR/brew-failed.out" 2>"$TMP_DIR/brew-failed.err"
[[ "$brew_attempt_count" -eq "$BREW_BUNDLE_MAX_ATTEMPTS" ]] ||
  fail "persistent Brew Bundle failure did not exhaust retries"
[[ "${#BREW_BUNDLE_FAILURES[@]}" -eq 1 ]] ||
  fail "persistent Brew Bundle failure was not recorded"
[[ "$(tail -n 1 "$brew_jobs_log")" == "bundle install --jobs=1 --file $TMP_DIR/Brewfile" ]] ||
  fail "final Brew Bundle retry did not reduce install concurrency"
[[ "$(tail -n 1 "$brew_env_log")" == "5|1" ]] ||
  fail "final Brew Bundle retry did not reduce download concurrency"

dependent_log="$TMP_DIR/dependents.log"
install_packages() {
  printf '%s\n' packages >>"$dependent_log"
  BREW_BUNDLE_FAILURES=("core packages: fixture")
}
print_brew_bundle_failures() { printf '%s\n' failures >>"$dependent_log"; }
run_cleanup() { printf '%s\n' cleanup >>"$dependent_log"; }
run_tool_installers() { printf '%s\n' tools >>"$dependent_log"; }
run_first_run_tasks() { printf '%s\n' first-run >>"$dependent_log"; }

set +e
install_declared_packages_and_dependents
dependent_status=$?
set -e
[[ "$dependent_status" -eq 1 ]] || fail "Brew Bundle failure did not stop the dependent phase"
[[ "$(<"$dependent_log")" == $'packages\nfailures' ]] ||
  fail "cleanup or Tool Installers ran after a Brew Bundle failure"

printf 'bootstrap test: passed\n'
