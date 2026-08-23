#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329 # Test doubles and globals feed sourced production functions.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL="$ROOT_DIR/install.sh"
TMP_DIR="$(mktemp -d)"
UNRESPONSIVE_BROKER_PID=""
UNRESPONSIVE_ASKPASS_PID=""

cleanup() {
  if [[ -n "$UNRESPONSIVE_ASKPASS_PID" ]]; then
    kill -KILL "$UNRESPONSIVE_ASKPASS_PID" >/dev/null 2>&1 || true
    wait "$UNRESPONSIVE_ASKPASS_PID" 2>/dev/null || true
  fi
  if [[ -n "$UNRESPONSIVE_BROKER_PID" ]]; then
    kill -KILL "$UNRESPONSIVE_BROKER_PID" >/dev/null 2>&1 || true
    wait "$UNRESPONSIVE_BROKER_PID" 2>/dev/null || true
  fi
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

homebrew_fixture_curl="$TMP_DIR/homebrew-curl"
homebrew_fixture_shasum="$TMP_DIR/homebrew-shasum"
homebrew_fixture_log="$TMP_DIR/homebrew-install.log"
cat >"$homebrew_fixture_curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while (($#)); do
  if [[ "$1" == --output ]]; then
    output="$2"
    shift
  elif [[ "$1" == https://* ]]; then
    url="$1"
  fi
  shift
done
printf '%s\n' '#!/usr/bin/env bash' \
  'printf "noninteractive=%s\\n" "${NONINTERACTIVE:-}" >"$HOMEBREW_FIXTURE_LOG"' >"$output"
printf '%s\n' "$url" >"$HOMEBREW_CURL_LOG"
EOF
cat >"$homebrew_fixture_shasum" <<EOF
#!/usr/bin/env bash
printf '%s  %s\n' '$HOMEBREW_INSTALL_SHA256' "\${3:-}"
EOF
chmod +x "$homebrew_fixture_curl" "$homebrew_fixture_shasum"
HOMEBREW_INSTALL_CURL="$homebrew_fixture_curl"
HOMEBREW_INSTALL_SHASUM="$homebrew_fixture_shasum"
HOMEBREW_FIXTURE_LOG="$homebrew_fixture_log"
HOMEBREW_CURL_LOG="$TMP_DIR/homebrew-curl.log"
export HOMEBREW_FIXTURE_LOG HOMEBREW_CURL_LOG
install_homebrew_from_official_commit
[[ "$(<"$homebrew_fixture_log")" == 'noninteractive=1' ]] ||
  fail "pinned Homebrew installer was not executed non-interactively"
[[ "$(<"$HOMEBREW_CURL_LOG")" == \
  "https://raw.githubusercontent.com/Homebrew/install/$HOMEBREW_INSTALL_COMMIT/install.sh" ]] ||
  fail "Homebrew bootstrap did not use the pinned upstream commit"

at_exit() { :; }
original_tmpdir="${TMPDIR:-}"
TMPDIR="$TMP_DIR"
SUDO_ASKPASS_RESPONSE_TIMEOUT_SECONDS=1
initialize_sudo_askpass_transport
if [[ -n "$original_tmpdir" ]]; then
  TMPDIR="$original_tmpdir"
else
  unset TMPDIR
fi
if grep -F '/usr/bin/security' "$SUDO_ASKPASS" >/dev/null; then
  fail "SUDO_ASKPASS still depends on a transient Keychain item"
fi
start_sudo_password_broker "fixture password"
broker_pid="$SUDO_ASKPASS_BROKER_PID"
askpass_pids=()
for askpass_index in 1 2 3 4; do
  "$SUDO_ASKPASS" >"$TMP_DIR/askpass-$askpass_index.out" &
  askpass_pids+=("$!")
done
for askpass_pid in "${askpass_pids[@]}"; do
  wait "$askpass_pid"
done
for askpass_index in 1 2 3 4; do
  [[ "$(<"$TMP_DIR/askpass-$askpass_index.out")" == "fixture password" ]] ||
    fail "concurrent SUDO_ASKPASS reader did not receive the in-memory credential"
done
stop_sudo_password_broker
if /bin/kill -0 "$broker_pid" >/dev/null 2>&1; then
  fail "SUDO_ASKPASS credential broker survived cleanup"
fi

# A live process can outlast a broken credential-serving loop. The askpass
# helper must time out its FIFO read and release the reader lock instead of
# blocking later Homebrew workers behind it indefinitely.
/bin/sleep 30 &
UNRESPONSIVE_BROKER_PID="$!"
printf '%s\n' "$UNRESPONSIVE_BROKER_PID" >"$SUDO_ASKPASS_DIR/broker-pid"
set +e
"$SUDO_ASKPASS" >"$TMP_DIR/unresponsive-askpass.out" \
  2>"$TMP_DIR/unresponsive-askpass.err" &
UNRESPONSIVE_ASKPASS_PID="$!"
askpass_finished=false
for _ in {1..40}; do
  if ! /bin/kill -0 "$UNRESPONSIVE_ASKPASS_PID" >/dev/null 2>&1; then
    askpass_finished=true
    break
  fi
  /bin/sleep 0.05
done
if [[ "$askpass_finished" == true ]]; then
  wait "$UNRESPONSIVE_ASKPASS_PID"
  unresponsive_askpass_status=$?
  UNRESPONSIVE_ASKPASS_PID=""
else
  unresponsive_askpass_status=124
fi
set -e
[[ "$unresponsive_askpass_status" -eq 1 ]] ||
  fail "SUDO_ASKPASS remained blocked when its credential broker stopped responding"
[[ ! -d "$SUDO_ASKPASS_DIR/reader-lock" ]] ||
  fail "unresponsive SUDO_ASKPASS reader retained the shared lock"
grep -F 'credential broker did not respond' \
  "$TMP_DIR/unresponsive-askpass.err" >/dev/null ||
  fail "unresponsive SUDO_ASKPASS reader did not explain its timeout"
kill "$UNRESPONSIVE_BROKER_PID"
wait "$UNRESPONSIVE_BROKER_PID" 2>/dev/null || true
UNRESPONSIVE_BROKER_PID=""
rm -f "$SUDO_ASKPASS_DIR/broker-pid"

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

xcode_setup_log="$TMP_DIR/xcode-setup.log"
xcode_developer_fixture="$TMP_DIR/Xcode.app/Contents/Developer"
mkdir -p "$xcode_developer_fixture"
set +e
(
  xcode_developer_dir() { printf '%s\n' "$xcode_developer_fixture"; }
  brew() { printf 'brew %s\n' "$*" >>"$xcode_setup_log"; }
  mas() { printf 'mas %s\n' "$*" >>"$xcode_setup_log"; }
  sudo_askpass() { printf 'sudo %s\n' "$*" >>"$xcode_setup_log"; }
  setup_full_xcode
) >"$TMP_DIR/xcode-setup.out" 2>"$TMP_DIR/xcode-setup.err"
xcode_setup_status=$?
set -e
[[ "$xcode_setup_status" -eq 0 ]] ||
  fail "full Xcode setup did not select and initialize the installed app"
cat >"$TMP_DIR/expected-xcode-setup.log" <<EOF
brew install mas
mas install 497799835
sudo /usr/bin/xcode-select --switch $xcode_developer_fixture
sudo /usr/bin/xcodebuild -license accept
sudo /usr/bin/xcodebuild -runFirstLaunch
EOF
cmp -s "$TMP_DIR/expected-xcode-setup.log" "$xcode_setup_log" ||
  fail "full Xcode setup ran in the wrong order"

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
  github_phase_preflight() { printf 'preflight-%s\n' "$1" >>"$orchestration_log"; }
  configure_and_print_install_plan() { printf '%s\n' selection >>"$orchestration_log"; }
  load_homebrew() { :; }
  install_homebrew() { printf '%s\n' homebrew >>"$orchestration_log"; }
  setup_full_xcode() { printf '%s\n' xcode >>"$orchestration_log"; }
  install_declared_packages_and_dependents() { printf '%s\n' bundles >>"$orchestration_log"; }
  print_next_steps() { :; }
  INSTALLED_MARKER="$TMP_DIR/installed"
  LEGACY_INSTALLED_MARKER="$TMP_DIR/legacy-installed"
  RUN_XCODE_SETUP=true
  main
)
[[ "$(<"$orchestration_log")" == $'prerequisites\nselection\npreflight-Homebrew bootstrap\nhomebrew\nxcode\nbundles' ]] ||
  fail "Homebrew was not preflighted or Xcode did not finish before dependent work"

password_capture_count=0
password_validation_count=0
capture_sudo_password() {
  password_capture_count=$((password_capture_count + 1))
  SUDO_ASKPASS_PASSWORD="fixture password"
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
stop_sudo_password_broker

password_capture_count=0
password_validation_count=0
start_sudo_password_broker() { :; }
stop_sudo_password_broker() { :; }
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
github_phase_preflight() { :; }
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
