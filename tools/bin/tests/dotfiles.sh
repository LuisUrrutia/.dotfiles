#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by fixture shells.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOTFILES_CLI="$ROOT_DIR/dotfiles"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'dotfiles test: %s\n' "$*" >&2
  exit 1
}

[[ -x "$DOTFILES_CLI" ]] || fail "root command is not executable"

root_help="$($DOTFILES_CLI help)"
[[ "$root_help" == *"Usage: dotfiles <command>"* ]] || fail "root help lacks usage"
[[ "$root_help" == *"install"* ]] || fail "root help lacks Install"
[[ "$root_help" == *"tool"* ]] || fail "root help lacks Tool Catalog"
[[ "$root_help" == *"verify"* ]] || fail "root help lacks Verification"
[[ "$root_help" == *"config"* && "$root_help" == *"update"* && "$root_help" == *"backup"* ]] ||
  fail "root help lacks a shipped phase"

real_install_help="$($DOTFILES_CLI help install)"
dev_summary="$(sed -n 's/^# summary: *//p' "$ROOT_DIR/brewfiles/profiles/dev" | head -1)"
[[ "$real_install_help" == *"dev"* && "$real_install_help" == *"$dev_summary"* ]] ||
  fail "Install help did not read profile metadata"

for incomplete_group in tool config backup; do
  "$DOTFILES_CLI" "$incomplete_group" >"$TMP_DIR/$incomplete_group-help.out" ||
    fail "$incomplete_group incomplete group did not return successful help"
  grep -q "Usage: dotfiles $incomplete_group" "$TMP_DIR/$incomplete_group-help.out" ||
    fail "$incomplete_group incomplete group lacks contextual usage"
done

[[ "$($DOTFILES_CLI help config status)" == *'Usage: dotfiles config status [tool]'* ]] ||
  fail "contextual Config Status help is missing"
[[ "$($DOTFILES_CLI config status --help)" == *'Usage: dotfiles config status [tool]'* ]] ||
  fail "Config Status --help is not contextual"
[[ "$($DOTFILES_CLI help backup all)" == *'Usage: dotfiles backup all'* ]] ||
  fail "contextual aggregate Backup help is missing"
[[ "$($DOTFILES_CLI backup all --help)" == *'Usage: dotfiles backup all'* ]] ||
  fail "aggregate Backup --help is not contextual"

set +e
"$DOTFILES_CLI" config status --dry-run >"$TMP_DIR/config-invalid.out" 2>"$TMP_DIR/config-invalid.err"
config_invalid_status=$?
set -e
[[ "$config_invalid_status" -eq 2 ]] || fail "Config Status accepted an operation flag"

mkdir -p "$TMP_DIR/bin"
ln -s "$DOTFILES_CLI" "$TMP_DIR/bin/dotfiles"

linked_help="$(cd "$TMP_DIR" && DOTFILES=/not/the/repository "$TMP_DIR/bin/dotfiles" help)"
[[ "$linked_help" == "$root_help" ]] || fail "installed symlink changed help"

mkdir -p "$TMP_DIR/chain"
ln -s "$TMP_DIR/bin/dotfiles" "$TMP_DIR/chain/second"
ln -s second "$TMP_DIR/chain/dotfiles"
chained_help="$(cd "$TMP_DIR" && DOTFILES=/not/the/repository "$TMP_DIR/chain/dotfiles" help)"
[[ "$chained_help" == "$root_help" ]] || fail "multi-symlink invocation changed help"

fixture_root="$TMP_DIR/repository"
fixture_log="$TMP_DIR/install.log"
mkdir -p "$fixture_root/cli" "$fixture_root/bootstrap" "$fixture_root/tools"
fixture_root="$(cd "$fixture_root" && pwd -P)"
cp "$DOTFILES_CLI" "$fixture_root/dotfiles"
cp "$ROOT_DIR"/cli/*.sh "$fixture_root/cli/"
cp "$ROOT_DIR/bootstrap/install-options.sh" "$ROOT_DIR/bootstrap/profiles.sh" \
  "$fixture_root/bootstrap/"
cp "$ROOT_DIR/tools/catalog.sh" "$fixture_root/tools/catalog.sh"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "root=%s\n" "$DOTFILES" >"$FIXTURE_LOG"' \
  'printf "cwd=%s\n" "$PWD" >>"$FIXTURE_LOG"' \
  'printf "arg=%s\n" "$@" >>"$FIXTURE_LOG"' \
  'printf "install stdout\n"' \
  'printf "install stderr\n" >&2' \
  'exit "${FIXTURE_STATUS:-0}"' \
  >"$fixture_root/install.sh"
chmod +x "$fixture_root/install.sh"

set +e
install_stdout="$(
  cd "$TMP_DIR"
  FIXTURE_LOG="$fixture_log" FIXTURE_STATUS=23 \
    "$fixture_root/dotfiles" install -n --profile web3,streaming \
    --profile=audio --no-upgrade 2>"$TMP_DIR/install.stderr"
)"
install_status=$?
set -e

[[ "$install_status" -eq 23 ]] || fail "Install did not preserve child status"
[[ "$install_stdout" == "install stdout" ]] || fail "Install changed child stdout"
[[ "$(<"$TMP_DIR/install.stderr")" == "install stderr" ]] || fail "Install changed child stderr"

expected_install_log="root=$fixture_root
cwd=$TMP_DIR
arg=-n
arg=--profile
arg=web3,streaming
arg=--profile=audio
arg=--no-upgrade"
[[ "$(<"$fixture_log")" == "$expected_install_log" ]] || fail "Install changed arguments, root, or cwd"

rm "$fixture_log"
set +e
FIXTURE_LOG="$fixture_log" "$fixture_root/dotfiles" install --profile --no-upgrade \
  >"$TMP_DIR/install-profile.out" 2>"$TMP_DIR/install-profile.err"
install_profile_status=$?
set -e
[[ "$install_profile_status" -eq 2 ]] || fail "Install accepted an option as a profile value"
[[ ! -e "$fixture_log" ]] || fail "invalid Install profile delegated to the Bootstrapper"

set +e
FIXTURE_LOG="$fixture_log" "$fixture_root/dotfiles" install --profile=--no-upgrade \
  >"$TMP_DIR/install-profile-equals.out" 2>"$TMP_DIR/install-profile-equals.err"
install_profile_equals_status=$?
set -e
[[ "$install_profile_equals_status" -eq 2 ]] ||
  fail "Install accepted an option as an equals-form profile value"
[[ ! -e "$fixture_log" ]] || fail "invalid equals-form profile delegated to the Bootstrapper"

install_help="$("$fixture_root/dotfiles" install --help)"
[[ "$install_help" == *"Usage: dotfiles install"* ]] || fail "Install help lacks usage"
[[ ! -e "$fixture_log" ]] || fail "Install help delegated to the Bootstrapper"

mkdir -p \
  "$fixture_root/tools/alpha" \
  "$fixture_root/tools/non-executable" \
  "$fixture_root/tools/zeta" \
  "$TMP_DIR/outside"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "root=%s\n" "$DOTFILES" >"$TOOL_LOG"' \
  'printf "cwd=%s\n" "$PWD" >>"$TOOL_LOG"' \
  'printf "tool stdout\n"' \
  'printf "tool stderr\n" >&2' \
  'exit 19' \
  >"$fixture_root/tools/alpha/install.sh"
cp "$fixture_root/tools/alpha/install.sh" "$fixture_root/tools/zeta/install.sh"
cp "$fixture_root/tools/alpha/install.sh" "$fixture_root/tools/non-executable/install.sh"
chmod +x "$fixture_root/tools/alpha/install.sh" "$fixture_root/tools/zeta/install.sh"

printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$TMP_DIR/outside/install.sh"
chmod +x "$TMP_DIR/outside/install.sh"
ln -s "$TMP_DIR/outside" "$fixture_root/tools/escape"

tool_list="$("$fixture_root/dotfiles" tool list)"
[[ "$tool_list" == $'alpha\nzeta' ]] || fail "Tool List did not return the safe executable catalog"

(
  DOTFILES="$fixture_root"
  # shellcheck disable=SC1090
  source "$ROOT_DIR/tools/catalog.sh"
  run_tool non-executable
) >"$TMP_DIR/tool-skip.out" 2>"$TMP_DIR/tool-skip.err" ||
  fail "unavailable Tool Installer did not degrade to a warning"
grep -F 'Warning: Tool Installer is unavailable or unsafe, skipping: non-executable' \
  "$TMP_DIR/tool-skip.err" >/dev/null ||
  fail "unavailable Tool Installer warning did not name the skipped tool"

tool_log="$TMP_DIR/tool.log"
set +e
tool_stdout="$(
  cd "$TMP_DIR"
  TOOL_LOG="$tool_log" "$fixture_root/dotfiles" tool apply alpha 2>"$TMP_DIR/tool.stderr"
)"
tool_status=$?
set -e

[[ "$tool_status" -eq 19 ]] || fail "Tool Apply did not preserve child status"
[[ "$tool_stdout" == "tool stdout" ]] || fail "Tool Apply changed child stdout"
actual_tool_stderr="$(<"$TMP_DIR/tool.stderr")"
[[ "$actual_tool_stderr" == "tool stderr" ]] ||
  fail "Tool Apply changed child stderr: $actual_tool_stderr"
expected_tool_log="root=$fixture_root
cwd=$TMP_DIR"
[[ "$(<"$tool_log")" == "$expected_tool_log" ]] || fail "Tool Apply changed root or cwd"

rm "$tool_log"
set +e
TOOL_LOG="$tool_log" "$fixture_root/dotfiles" tool apply alpha extra \
  >"$TMP_DIR/tool-extra.out" 2>"$TMP_DIR/tool-extra.err"
tool_extra_status=$?
set -e
[[ "$tool_extra_status" -eq 2 ]] || fail "Tool Apply extra argument is not a usage error"
[[ ! -e "$tool_log" ]] || fail "invalid Tool Apply invoked the installer"

tool_help="$("$fixture_root/dotfiles" help tool)"
[[ "$tool_help" == *"Usage: dotfiles tool"* ]] || fail "Tool help lacks usage"

stow_home="$TMP_DIR/stow-home"
mkdir -p "$stow_home"
stow --no-folding --restow -d "$ROOT_DIR/tools/bin" -t "$stow_home" config
[[ -L "$stow_home/.local/bin/dotfiles" ]] || fail "bin package did not install the command link"

stowed_help="$(cd "$TMP_DIR" && "$stow_home/.local/bin/dotfiles" help)"
[[ "$stowed_help" == "$root_help" ]] || fail "Stowed command did not reach the root dispatcher"

mkdir -p "$fixture_root/verification"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "arg=%s\n" "$@" >"$VERIFY_LOG"' \
  'printf "verify stdout\n"' \
  'printf "verify stderr\n" >&2' \
  'exit 17' \
  >"$fixture_root/verification/run.sh"
chmod +x "$fixture_root/verification/run.sh"

set +e
verify_stdout="$(VERIFY_LOG="$TMP_DIR/verify.log" "$fixture_root/dotfiles" verify 2>"$TMP_DIR/verify.stderr")"
verify_status=$?
set -e
[[ "$verify_status" -eq 17 ]] || fail "Verify did not preserve runner status"
[[ "$verify_stdout" == 'verify stdout' ]] || fail "Verify changed runner stdout"
[[ "$(<"$TMP_DIR/verify.stderr")" == 'verify stderr' ]] || fail "Verify changed runner stderr"
[[ "$(<"$TMP_DIR/verify.log")" == 'arg=' ]] || fail "Verify changed runner arguments"

rm "$TMP_DIR/verify.log"
verify_help="$("$fixture_root/dotfiles" verify --help)"
[[ "$verify_help" == *"Usage: dotfiles verify"* ]] || fail "Verify help lacks usage"
[[ ! -e "$TMP_DIR/verify.log" ]] || fail "Verify help delegated to the runner"

set +e
VERIFY_LOG="$TMP_DIR/verify.log" "$fixture_root/dotfiles" verify --unexpected \
  >"$TMP_DIR/verify-invalid.out" 2>"$TMP_DIR/verify-invalid.err"
verify_invalid_status=$?
set -e
[[ "$verify_invalid_status" -eq 2 ]] || fail "Unknown Verify option is not a usage error"
[[ ! -e "$TMP_DIR/verify.log" ]] || fail "Unknown Verify option delegated to the runner"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'trap '\''printf "%s\n" stopped >"$INSTALL_SIGNAL_STOPPED"; exit 143'\'' TERM' \
  'printf "%s\n" ready >"$INSTALL_SIGNAL_READY"' \
  'while :; do /bin/sleep 0.1; done' \
  >"$fixture_root/install.sh"
chmod +x "$fixture_root/install.sh"

INSTALL_SIGNAL_READY="$TMP_DIR/install-signal-ready" \
  INSTALL_SIGNAL_STOPPED="$TMP_DIR/install-signal-stopped" \
  "$fixture_root/dotfiles" install >"$TMP_DIR/install-signal.out" 2>"$TMP_DIR/install-signal.err" &
install_signal_pid=$!

attempt=0
while [[ "$attempt" -lt 100 && ! -e "$TMP_DIR/install-signal-ready" ]]; do
  /bin/sleep 0.02
  attempt=$((attempt + 1))
done
if [[ ! -e "$TMP_DIR/install-signal-ready" ]]; then
  cat "$TMP_DIR/install-signal.err" >&2
  fail "Install signal fixture did not start"
fi
kill -TERM "$install_signal_pid"
if wait "$install_signal_pid"; then
  install_signal_status=0
else
  install_signal_status=$?
fi
[[ "$install_signal_status" -eq 143 ]] || fail "Install did not preserve TERM status"
[[ -e "$TMP_DIR/install-signal-stopped" ]] || fail "Install did not exec its delegate"
