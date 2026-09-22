#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOTFILES="$ROOT_DIR"
DOTFILES_MACOS_NO_MAIN=true
export DOTFILES DOTFILES_MACOS_NO_MAIN

# shellcheck disable=SC1090
source "$ROOT_DIR/tools/macos/install.sh"

fail() {
  printf 'macOS install test: %s\n' "$*" >&2
  exit 1
}

reset_macos_counters() {
  macos_error_count=0
  macos_step_failed=0
  macos_failed_steps=()
  macos_skipped_settings=()
}

DOTFILES_HARDWARE_HOSTNAME=""
run_macos_step configure_hostname 2>/dev/null
[[ "$macos_error_count" -eq 0 ]] ||
  fail "an absent optional hostname was logged as an error"
[[ "${#macos_failed_steps[@]}" -eq 0 ]] ||
  fail "an absent optional hostname was added to the failed-step summary"

DOTFILES_HARDWARE_HOSTNAME="invalid hostname"
run_macos_step configure_hostname 2>/dev/null
[[ "$macos_error_count" -eq 1 ]] ||
  fail "an invalid hostname logged $macos_error_count errors instead of one"
[[ "${macos_failed_steps[*]}" == *configure_hostname* ]] ||
  fail "an invalid hostname was omitted from the failed-step summary"

# A failure raised deep in a call chain makes every enclosing function return
# it as their last command, and bash re-fires ERR for each of those without
# refreshing BASH_COMMAND. Those replays must not reach the log.
deep_failure_leaf() { /usr/bin/false; }
deep_failure_middle() { deep_failure_leaf; }
step_with_deep_failure() { deep_failure_middle; }

reset_macos_counters
deep_log="$(mktemp)"
# not a command substitution: that would run the step in a subshell and lose
# the counters it is asserting on
run_macos_step step_with_deep_failure 2>"$deep_log"
deep_step_status=$?
deep_output="$(cat "$deep_log")"
rm -f "$deep_log"
[[ "$deep_step_status" -eq 0 ]] ||
  fail "a logged macOS preference failure escaped the step boundary"
[[ "$macos_error_count" -eq 1 ]] ||
  fail "one deep failure logged $macos_error_count errors instead of one"
[[ "$deep_output" != *macos_error_trap* ]] ||
  fail "the ERR trap marker leaked into the log as an error"
[[ "$deep_output" == *"deep_failure_leaf<-deep_failure_middle<-step_with_deep_failure"* ]] ||
  fail "the log omitted the call chain leading to the failure"

# sudo_askpass ends in a bare `return`, whose frame bash has already popped by
# the time ERR fires, so the chain names its caller. That is what makes an
# otherwise contextless "return" attributable to a step.
returning_leaf() { return 1; }
step_with_returning_leaf() { returning_leaf; }

reset_macos_counters
return_log="$(mktemp)"
run_macos_step step_with_returning_leaf 2>"$return_log"
return_output="$(cat "$return_log")"
rm -f "$return_log"
[[ "$macos_error_count" -eq 1 ]] ||
  fail "a bare-return failure logged $macos_error_count errors instead of one"
[[ "$return_output" == *"in step_with_returning_leaf: return 1"* ]] ||
  fail "a bare-return failure was logged without the frame that owns it"

# Distinct failures reporting the same command text are distinct log entries;
# collapsing them hid real failures behind whichever one happened first.
step_with_repeated_failures() {
  deep_failure_leaf
  deep_failure_leaf
  return 0
}

reset_macos_counters
run_macos_step step_with_repeated_failures 2>/dev/null
[[ "$macos_error_count" -eq 2 ]] ||
  fail "two identical-looking failures logged $macos_error_count errors instead of two"

# summarize_macos_errors expands its arrays, and bash 3.2 (the only bash on a
# stock macOS) treats an empty array as unset under `set -u`
reset_macos_counters
macos_error_count=1
summarize_macos_errors 2>/dev/null ||
  fail "the summary aborted on empty failed-step and skipped-setting arrays"

# defaults_try records a permission failure as a skip and lets the step finish
reset_macos_counters
defaults_try "unwritable test domain" \
  write /nonexistent/macos-install-test SomeKey -bool true 2>/dev/null
[[ "$macos_error_count" -eq 0 ]] ||
  fail "a best-effort setting was counted as a hard error"
[[ "${#macos_skipped_settings[@]}" -eq 1 ]] ||
  fail "a failed best-effort setting was not recorded as a skip"

# What defaults printed is the only thing separating a missing permission from
# a malformed invocation. Without it in the message, a typo in these flags is
# indistinguishable from an expected TCC denial.
reset_macos_counters
skip_log="$(mktemp)"
defaults_try "unwritable test domain" \
  write /nonexistent/macos-install-test SomeKey -bool true 2>"$skip_log"
skip_output="$(cat "$skip_log")"
defaults_try "malformed invocation" \
  write com.apple.finder MacosInstallTestKey -notaflag true 2>>"$skip_log"
malformed_output="$(sed -n '2p' "$skip_log")"
rm -f "$skip_log"
[[ "$skip_output" == *"Could not write domain"* ]] ||
  fail "the skip message dropped the error defaults reported"
[[ "$malformed_output" != *"Could not write domain"* ]] ||
  fail "a malformed invocation was reported as a permission failure"

# configure_screen_lock prompts for the account password, so it has to bow out
# cleanly when nothing can answer the prompt rather than hanging the install
reset_macos_counters
run_macos_step configure_screen_lock </dev/null 2>/dev/null
[[ "$macos_error_count" -eq 0 ]] ||
  fail "the screen lock step reported an error with no terminal to prompt on"
[[ "${#macos_failed_steps[@]}" -eq 0 ]] ||
  fail "the screen lock step was marked failed with no terminal to prompt on"

captured_defaults_calls=""
defaults() { captured_defaults_calls="${captured_defaults_calls}$*\n"; }
configure_keyboard_shortcuts
[[ "$captured_defaults_calls" == *"com.apple.Siri ConfirmSiriInvokedViaEitherCmdTwice -bool false"* ]] ||
  fail "the Type to Siri opt-in prompt was not disabled"
[[ "$captured_defaults_calls" == *"AppleSymbolicHotKeys -dict-add 176"* ]] ||
  fail "the double-Command Type to Siri shortcut was not disabled"
[[ "$captured_defaults_calls" == *"SAE1.0"* ]] ||
  fail "the Type to Siri shortcut omitted its symbolic-hotkey type"
unset -f defaults

captured_osascript=""
osascript() { captured_osascript="$*"; }
configure_login_items
[[ "$captured_osascript" == *'exists login item "DisplayLink Manager"'* ]] ||
  fail "the DisplayLink login item removal was not guarded for an absent item"
[[ "$captured_osascript" == *'delete login item "DisplayLink Manager"'* ]] ||
  fail "the DisplayLink login item was not removed"
unset -f osascript

# The delete-conversation shortcut is matched against the menu title macOS
# displays, so it has to cover more than English, and it has to survive ChatKit
# moving: an empty -dict-add would delete the key instead of adding to it.
reset_macos_counters
captured_dict_args=()
defaults_try() { captured_dict_args=("$@"); }

DOTFILES_CHATKIT_LOCTABLE="/nonexistent/ChatKit.loctable"
configure_messages_shortcuts
[[ "${#captured_dict_args[@]}" -gt 4 ]] ||
  fail "a missing ChatKit loctable left the shortcut dict empty"
[[ "${captured_dict_args[*]}" == *"Eliminar conversación…"* ]] ||
  fail "the fallback shortcut titles cover only English"

DOTFILES_CHATKIT_LOCTABLE=""
if [[ -r "/System/iOSSupport/System/Library/PrivateFrameworks/ChatKit.framework/Versions/A/Resources/ChatKit.loctable" ]] && command -v jq >/dev/null 2>&1; then
  configure_messages_shortcuts
  # Messages switches to the plural title once several conversations are
  # selected, so binding only the singular loses the shortcut for bulk deletes
  [[ "${captured_dict_args[*]}" == *"Delete Conversation…"* ]] ||
    fail "the shortcut dict omitted the singular English menu title"
  [[ "${captured_dict_args[*]}" == *"Delete Conversations…"* ]] ||
    fail "the shortcut dict omitted the plural English menu title"
  [[ "${captured_dict_args[*]}" == *"Eliminar conversación…"* ]] ||
    fail "the shortcut dict omitted the Spanish menu title"
fi

# Every title has to be followed by its shortcut; an odd count means a title
# would silently become the value of the one before it
shortcut_pair_count=$((${#captured_dict_args[@]} - 5))
[[ $((shortcut_pair_count % 2)) -eq 0 ]] ||
  fail "the shortcut dict has a title without a key equivalent"

unset -f defaults_try
# shellcheck disable=SC1090
source "$ROOT_DIR/tools/macos/install.sh"

# request_full_disk_access used to open the Settings pane and then have
# close_system_settings quit it on the very next line of main, so the pane the
# warning points at was gone before anyone could use it. Warning and pane are
# now separate calls, at opposite ends of the run.
opened_panes=""
open() { opened_panes="${opened_panes}$* "; }
has_full_disk_access() { return 1; }

macos_needs_full_disk_access=false
warn_missing_full_disk_access 2>/dev/null
[[ "$macos_needs_full_disk_access" == true ]] ||
  fail "a missing Full Disk Access permission went unrecorded"
[[ -z "$opened_panes" ]] ||
  fail "the Settings pane opened early, where close_system_settings closes it"

open_full_disk_access_pane 2>/dev/null
[[ "$opened_panes" == *Privacy_AllFiles* ]] ||
  fail "the Full Disk Access pane never opened at the end of the run"

# Nothing should open when the permission is already granted
has_full_disk_access() { return 0; }
macos_needs_full_disk_access=false
opened_panes=""
warn_missing_full_disk_access 2>/dev/null
open_full_disk_access_pane 2>/dev/null
[[ -z "$opened_panes" ]] ||
  fail "a Settings pane opened even though Full Disk Access was granted"

unset -f open has_full_disk_access

# A step defined but never registered in main() is dead code that still looks
# live: it passes shellcheck, and its own assertions keep passing, while none
# of its settings are ever applied.
install_script="$ROOT_DIR/tools/macos/install.sh"
defined_steps="$(grep -oE '^configure_[a-z_]+\(\)' "$install_script" | sed 's/()//' | sort)"
registered_steps="$(sed -n '/^main() {/,/^}/p' "$install_script" |
  grep -oE 'run_macos_step [a-z_]+' | awk '{print $2}' | sort)"

unregistered="$(comm -23 <(printf '%s\n' "$defined_steps") <(printf '%s\n' "$registered_steps"))"
[[ -z "$unregistered" ]] ||
  fail "configure steps never run from main(): ${unregistered//$'\n'/ }"

log_fixture_dir="$(mktemp -d)"
macos_install_log="$log_fixture_dir/logs/macos-install.log"
macos_log_pipe_dir=""
macos_log_tee_pids=()
setup_macos_log
echo "log permission fixture"
close_macos_log
[[ "$(stat -f '%Sp' "$log_fixture_dir/logs")" == "drwx------" ]] ||
  fail "the macOS log directory is accessible to other users"
[[ "$(stat -f '%Sp' "$macos_install_log")" == "-rw-------" ]] ||
  fail "the macOS setup log is accessible to other users"
rm -rf "$log_fixture_dir"

# shellcheck disable=SC1090
source "$ROOT_DIR/tools/macos/install.sh"
for step in $registered_steps; do
  declare -f "$step" >/dev/null ||
    fail "main() runs '$step', which is not defined"
done

# The recovery key must not be copied into the setup log.
key_dir="$(mktemp -d)"
key_file="$key_dir/FileVault Recovery Key.txt"
# shellcheck disable=SC2329  # called indirectly, through the function under test
fdesetup() { printf 'Recovery key = TEST-KEY-DO-NOT-LOG\n'; }
sudo_askpass() { "$@"; }

key_stdout="$(write_filevault_recovery_key "$key_file")"
[[ "$key_stdout" != *TEST-KEY-DO-NOT-LOG* ]] ||
  fail "the FileVault recovery key reached stdout, which the setup log captures"
grep -q "TEST-KEY-DO-NOT-LOG" "$key_file" ||
  fail "the FileVault recovery key never reached the key file"
[[ "$(stat -f '%Sp' "$key_file")" == "-rw-------" ]] ||
  fail "the FileVault key file is readable by more than its owner"

# A key file that cannot be opened has to fail before fdesetup encrypts the
# disk, not after, when the key it printed is already unrecoverable
# shellcheck disable=SC2329
fdesetup() { touch "$key_dir/fdesetup-called"; return 1; }
existing_file="$key_dir/existing.txt"
printf 'preserve existing data\n' >"$existing_file"
chmod 644 "$existing_file"
ln -s "$existing_file" "$key_dir/existing-link"
ln -s "$key_dir/absent-target" "$key_dir/dangling-link"
mkfifo "$key_dir/existing-pipe"

for destination in "$key_dir/missing/key.txt" "$existing_file" \
  "$key_dir/existing-link" "$key_dir/dangling-link" "$key_dir/existing-pipe"; do
  ! write_filevault_recovery_key "$destination" 2>/dev/null ||
    fail "an unsafe key destination was accepted: $destination"
done

[[ ! -e "$key_dir/fdesetup-called" ]] ||
  fail "fdesetup ran before a safe key file was opened"
[[ "$(cat "$existing_file")" == "preserve existing data" ]] ||
  fail "an existing destination was changed"
[[ "$(stat -f '%Sp' "$existing_file")" == "-rw-r--r--" ]] ||
  fail "an existing destination's permissions were changed"
[[ -L "$key_dir/existing-link" && -L "$key_dir/dangling-link" && ! -e "$key_dir/absent-target" ]] ||
  fail "a key destination symlink was changed or followed"

failed_key_file="$key_dir/failed-key.txt"
! write_filevault_recovery_key "$failed_key_file" ||
  fail "failed FileVault enablement was reported as successful"
[[ -e "$key_dir/fdesetup-called" && ! -e "$failed_key_file" ]] ||
  fail "failed FileVault enablement did not clean up its own key file"

rm -rf "$key_dir"
unset -f fdesetup sudo_askpass

key_home="$(mktemp -d)"
mkdir -p "$key_home/Desktop"
printf 'preserve old recovery file\n' >"$key_home/Desktop/FileVault Recovery Key.txt"
cat >"$key_home/enable.sh" <<'BASH'
source "$DOTFILES/tools/macos/install.sh"
fdesetup() {
  case "$1" in
  status) printf 'FileVault is Off.\n' ;;
  enable) printf 'TEST-KEY-DO-NOT-LOG\n' ;;
  esac
}
sudo_askpass() { "$@"; }
configure_filevault
configure_filevault
BASH

# Give only the fake enablement a terminal so the production interactive gate runs.
HOME="$key_home" /usr/bin/script -q /dev/null /bin/bash "$key_home/enable.sh" \
  </dev/null >"$key_home/output" 2>&1

[[ "$(cat "$key_home/Desktop/FileVault Recovery Key.txt")" == "preserve old recovery file" ]] ||
  fail "FileVault enablement changed the previous recovery file"
! grep -q 'TEST-KEY-DO-NOT-LOG' "$key_home/output" ||
  fail "FileVault enablement exposed a recovery key in its output"
key_count=0
for key_directory in "$key_home/Desktop"/FileVault\ Recovery\ Key.*; do
  [[ -d "$key_directory" ]] || continue
  [[ "$(stat -f '%Sp' "$key_directory")" == "drwx------" ]] ||
    fail "the recovery-key directory is not private"
  [[ "$(stat -f '%Sp' "$key_directory/recovery-key.txt")" == "-rw-------" ]] ||
    fail "the recovery-key file is not private"
  grep -q 'TEST-KEY-DO-NOT-LOG' "$key_directory/recovery-key.txt" ||
    fail "the recovery-key file is missing the command output"
  key_count=$((key_count + 1))
done
[[ "$key_count" -eq 2 ]] || fail "FileVault enablements did not create unique destinations"
rm -rf "$key_home"

# shellcheck disable=SC1090
source "$ROOT_DIR/tools/macos/install.sh"

# The log captures stdout as well as stderr; it is an install log, not an
# error log, and command output is what explains a failure
log_dir="$(mktemp -d)"
trap 'rm -rf "$log_dir"' EXIT
(
  macos_install_log="$log_dir/macos-install.log"
  macos_log_pipe_dir=""
  macos_log_tee_pids=()
  setup_macos_log
  echo "test-stdout-line"
  echo "test-stderr-line" >&2
  close_macos_log
) >/dev/null 2>&1
grep -q "test-stdout-line" "$log_dir/macos-install.log" ||
  fail "stdout was not captured in the macOS setup log"
grep -q "test-stderr-line" "$log_dir/macos-install.log" ||
  fail "stderr was not captured in the macOS setup log"

printf 'macOS install test: passed\n'
