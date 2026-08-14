#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016,SC2329 # Fixture source and indirect overrides are intentional.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
FIXTURE_ROOT="$TMP_DIR/repository"
HOME_DIR="$TMP_DIR/home"
FAKE_BIN="$TMP_DIR/bin"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

test_fail() {
  printf 'config resolve test: %s\n' "$*" >&2
  exit 1
}

mkdir -p \
  "$FIXTURE_ROOT/config" \
  "$FIXTURE_ROOT/tools/fixture/config/.config/fixture" \
  "$HOME_DIR/.config/fixture" \
  "$FAKE_BIN"
cp "$ROOT_DIR/config/run.sh" "$FIXTURE_ROOT/config/run.sh"
printf '%s\n' tracked >"$FIXTURE_ROOT/tools/fixture/config/.config/fixture/settings.txt"

git -C "$FIXTURE_ROOT" init -q
git -C "$FIXTURE_ROOT" config user.name Fixture
git -C "$FIXTURE_ROOT" config user.email fixture@example.com
git -C "$FIXTURE_ROOT" add config/run.sh tools/fixture/config
git -C "$FIXTURE_ROOT" commit -qm fixture

source_path="$FIXTURE_ROOT/tools/fixture/config/.config/fixture/settings.txt"
live_path="$HOME_DIR/.config/fixture/settings.txt"
printf '%s\n' live >"$live_path"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >"$AGENT_LOG"' \
  'printf "cwd=%s\n" "$PWD" >>"$AGENT_LOG"' \
  'if [[ -n "${RESOLVE_ORDER_LOG:-}" ]]; then' \
  '  [[ -f "$RESOLVE_CONSENT_MARKER" ]] || exit 90' \
  '  backup_count="$(find "$XDG_DATA_HOME/dotfiles/config-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d " ")"' \
  '  [[ "$backup_count" -gt "$RESOLVE_BACKUP_BASELINE" ]] || exit 91' \
  '  printf "%s\n" launch >>"$RESOLVE_ORDER_LOG"' \
  'fi' \
  'if [[ "${RESOLVE_LINK:-true}" == true ]]; then' \
  '  rm "$RESOLVE_LIVE"' \
  '  ln -s "$RESOLVE_SOURCE" "$RESOLVE_LIVE"' \
  'fi' \
  'exit "${AGENT_STATUS:-0}"' \
  >"$FAKE_BIN/claude"
chmod +x "$FAKE_BIN/claude"
cp "$FAKE_BIN/claude" "$FAKE_BIN/codex"

DOTFILES_CONFIG_NO_MAIN=true
DOTFILES="$FIXTURE_ROOT"
HOME="$HOME_DIR"
XDG_DATA_HOME="$TMP_DIR/data"
PATH="$FAKE_BIN:$PATH"
export DOTFILES_CONFIG_NO_MAIN DOTFILES HOME XDG_DATA_HOME PATH
# shellcheck disable=SC1090
source "$FIXTURE_ROOT/config/run.sh"

config_is_interactive() { return 0; }
confirm_provider() {
  local backup_count=""
  if [[ -n "${RESOLVE_ORDER_LOG:-}" ]]; then
    backup_count="$(find "$XDG_DATA_HOME/dotfiles/config-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    [[ "$backup_count" == "$RESOLVE_BACKUP_BASELINE" ]] || return 92
    printf '%s\n' disclosure-consent >>"$RESOLVE_ORDER_LOG"
    printf '%s\n' confirmed >"$RESOLVE_CONSENT_MARKER"
  fi
  return 0
}

claude_only_bin="$TMP_DIR/claude-only-bin"
mkdir -p "$claude_only_bin"
cp "$FAKE_BIN/claude" "$claude_only_bin/claude"
automatic_provider="$(
  PATH="$claude_only_bin:/usr/bin:/bin"
  export PATH
  select_agent ""
)"
[[ "$automatic_provider" == claude ]] || test_fail "Resolve did not auto-select the sole agent"

set +e
(
  PATH="$claude_only_bin:/usr/bin:/bin"
  export PATH
  select_agent codex
) >"$TMP_DIR/requested-missing.out" 2>"$TMP_DIR/requested-missing.err"
requested_missing_status=$?
set -e
[[ "$requested_missing_status" -eq 1 ]] || test_fail "Resolve accepted a requested missing agent"

selected_both="$(printf '%s\n' codex | select_agent "" 2>"$TMP_DIR/select-both.err")"
[[ "$selected_both" == codex ]] || test_fail "Resolve did not honor an interactive agent choice"

first_backup_one="$TMP_DIR/concurrent-backup-one"
first_backup_two="$TMP_DIR/concurrent-backup-two"
new_resolve_backup fixture .config/fixture/settings.txt >"$first_backup_one" &
first_backup_pid=$!
new_resolve_backup fixture .config/fixture/settings.txt >"$first_backup_two" &
second_backup_pid=$!
wait "$first_backup_pid"
wait "$second_backup_pid"
[[ "$(<"$first_backup_one")" != "$(<"$first_backup_two")" ]] ||
  test_fail "concurrent Resolve backups reused one directory"
[[ -d "$(<"$first_backup_one")" && -d "$(<"$first_backup_two")" ]] ||
  test_fail "concurrent Resolve backup reservation was not durable"

RESOLVE_ORDER_LOG="$TMP_DIR/resolve-order.log"
RESOLVE_CONSENT_MARKER="$TMP_DIR/resolve-consent"
RESOLVE_BACKUP_BASELINE="$(find "$XDG_DATA_HOME/dotfiles/config-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
export RESOLVE_ORDER_LOG RESOLVE_CONSENT_MARKER RESOLVE_BACKUP_BASELINE

AGENT_LOG="$TMP_DIR/claude.log"
RESOLVE_LIVE="$live_path"
RESOLVE_SOURCE="$source_path"
AGENT_STATUS=27
export AGENT_LOG RESOLVE_LIVE RESOLVE_SOURCE AGENT_STATUS

set +e
resolve_command fixture .config/fixture/settings.txt --agent claude \
  >"$TMP_DIR/resolve.out" 2>"$TMP_DIR/resolve.err"
resolve_status=$?
set -e

[[ "$resolve_status" -eq 0 ]] || test_fail "final linked state did not override agent failure"
[[ "$(<"$RESOLVE_ORDER_LOG")" == $'disclosure-consent\nlaunch' ]] ||
  test_fail "Resolve did not consent, back up, and launch in order"
unset RESOLVE_ORDER_LOG RESOLVE_CONSENT_MARKER RESOLVE_BACKUP_BASELINE
grep -F -- '--dangerously-skip-permissions' "$AGENT_LOG" >/dev/null ||
  test_fail "Claude did not receive its required permission flag"
grep -F 'cwd='"$FIXTURE_ROOT" "$AGENT_LOG" >/dev/null || test_fail "agent did not start at repository root"
grep -F '.config/fixture/settings.txt' "$AGENT_LOG" >/dev/null || test_fail "agent context omitted selected path"
grep -F 'exited with status 27' "$TMP_DIR/resolve.err" >/dev/null || test_fail "agent failure did not warn"
[[ -L "$live_path" ]] || test_fail "fixture agent did not leave linked state"

backup_path="$(sed -n 's/^Backup: //p' "$TMP_DIR/resolve.out" | head -n 1)"
[[ -f "$backup_path/tracked/fixture/.config/fixture/settings.txt" ]] ||
  test_fail "Resolve did not back up tracked source"
[[ "$(<"$backup_path/live/.config/fixture/settings.txt")" == live ]] ||
  test_fail "Resolve did not back up live source"

rm "$live_path"
ln -s "$TMP_DIR/foreign-target" "$live_path"
AGENT_STATUS=0
export AGENT_STATUS
set +e
resolve_command fixture .config/fixture/settings.txt --agent claude \
  >"$TMP_DIR/resolve-link.out" 2>"$TMP_DIR/resolve-link.err"
resolve_link_status=$?
set -e
[[ "$resolve_link_status" -eq 0 ]] || test_fail "foreign-link Resolve did not finish linked"
link_backup="$(sed -n 's/^Backup: //p' "$TMP_DIR/resolve-link.out" | head -n 1)"
[[ -L "$link_backup/live/.config/fixture/settings.txt" ]] || test_fail "Resolve dereferenced backed-up symlink"
[[ "$(readlink "$link_backup/live/.config/fixture/settings.txt")" == "$TMP_DIR/foreign-target" ]] ||
  test_fail "Resolve did not preserve literal symlink target"

rm "$live_path"
printf '%s\n' live >"$live_path"
backup_count_before="$(find "$XDG_DATA_HOME/dotfiles/config-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
rm -f "$AGENT_LOG"
set +e
(
  confirm_provider() { return 1; }
  resolve_command fixture .config/fixture/settings.txt --agent claude
) >"$TMP_DIR/resolve-declined.out" 2>"$TMP_DIR/resolve-declined.err"
declined_status=$?
set -e
[[ "$declined_status" -eq 1 ]] || test_fail "Resolve ignored declined provider consent"
[[ ! -e "$AGENT_LOG" ]] || test_fail "declined Resolve launched an agent"
backup_count_after="$(find "$XDG_DATA_HOME/dotfiles/config-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[[ "$backup_count_after" == "$backup_count_before" ]] ||
  test_fail "declined Resolve created a backup"

set +e
(
  PATH=/usr/bin:/bin
  export PATH
  resolve_command fixture .config/fixture/settings.txt
) >"$TMP_DIR/resolve-absent.out" 2>"$TMP_DIR/resolve-absent.err"
absent_status=$?
set -e
[[ "$absent_status" -eq 1 ]] || test_fail "Resolve accepted an absent provider"
grep -F 'neither Claude nor Codex is installed' "$TMP_DIR/resolve-absent.err" >/dev/null ||
  test_fail "Resolve hid the absent-provider error"

AGENT_LOG="$TMP_DIR/codex.log"
AGENT_STATUS=0
RESOLVE_LINK=true
export AGENT_LOG AGENT_STATUS RESOLVE_LINK
resolve_command fixture .config/fixture/settings.txt --agent codex \
  >"$TMP_DIR/resolve-codex.out" 2>"$TMP_DIR/resolve-codex.err"
grep -F -- '--dangerously-bypass-approvals-and-sandbox' "$AGENT_LOG" >/dev/null ||
  test_fail "Codex did not receive its required permission flag"

rm "$live_path"
printf '%s\n' unresolved >"$live_path"
AGENT_LOG="$TMP_DIR/incomplete.log"
RESOLVE_LINK=false
export AGENT_LOG RESOLVE_LINK
if resolve_command fixture .config/fixture/settings.txt --agent claude \
  >"$TMP_DIR/resolve-incomplete.out" 2>"$TMP_DIR/resolve-incomplete.err"; then
  incomplete_status=0
else
  incomplete_status=$?
fi
[[ "$incomplete_status" -eq 1 ]] || test_fail "Resolve accepted an incomplete final state"
grep -F 'resolve incomplete; backup preserved' "$TMP_DIR/resolve-incomplete.err" >/dev/null ||
  test_fail "incomplete Resolve did not preserve and report its backup"
incomplete_backup="$(sed -n 's/^Backup: //p' "$TMP_DIR/resolve-incomplete.out" | head -n 1)"
[[ -d "$incomplete_backup" ]] || test_fail "incomplete Resolve backup is missing"
[[ ! -L "$live_path" && "$(<"$live_path")" == unresolved ]] ||
  test_fail "incomplete Resolve changed the agent's final state"

blocked_data="$TMP_DIR/blocked-resolution-data"
printf '%s\n' blocker >"$blocked_data"
rm -f "$AGENT_LOG"
set +e
(
  XDG_DATA_HOME="$blocked_data"
  export XDG_DATA_HOME
  resolve_command fixture .config/fixture/settings.txt --agent claude
) >"$TMP_DIR/resolve-backup-failure.out" 2>"$TMP_DIR/resolve-backup-failure.err"
backup_failure_status=$?
set -e
[[ "$backup_failure_status" -eq 1 ]] ||
  test_fail "Resolve continued after backup creation failed"
[[ ! -e "$AGENT_LOG" ]] || test_fail "Resolve launched an agent without a safety backup"
grep -F 'could not create resolution backup' "$TMP_DIR/resolve-backup-failure.err" >/dev/null ||
  test_fail "Resolve hid its backup creation failure"
