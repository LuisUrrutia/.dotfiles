#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippet is evaluated by fake backup owners.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
FIXTURE_ROOT="$TMP_DIR/repository"
FAKE_BIN="$TMP_DIR/bin"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'backup test: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$FIXTURE_ROOT/cli" "$FIXTURE_ROOT/maintenance" "$FAKE_BIN"
cp "$ROOT_DIR/dotfiles" "$FIXTURE_ROOT/dotfiles"
cp "$ROOT_DIR"/cli/*.sh "$FIXTURE_ROOT/cli/"
cp "$ROOT_DIR/maintenance/backup.sh" "$FIXTURE_ROOT/maintenance/backup.sh"
chmod +x "$FIXTURE_ROOT/dotfiles" "$FIXTURE_ROOT/maintenance/backup.sh"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'name="$(basename "$0" -config)"' \
  'printf "%s stdout\n" "$name"' \
  'printf "%s stderr\n" "$name" >&2' \
  'printf "%s %s\n" "$name" "$*" >>"$BACKUP_LOG"' \
  'if [[ "${BACKUP_AGGREGATE:-false}" == true ]]; then' \
  '  printf "%s\n" "$name" >&3' \
  '  if [[ -n "${BACKUP_RELEASE_DIR:-}" ]]; then IFS= read -r _ <"$BACKUP_RELEASE_DIR/$name"; fi' \
  '  if [[ -n "${BACKUP_ARTIFACT_DIR:-}" ]]; then printf "artifact\n" >"$BACKUP_ARTIFACT_DIR/$name"; fi' \
  '  if [[ "${BACKUP_SIGNAL_FIXTURE:-false}" == true ]]; then' \
  '    trap '\''printf "%s\n" "$name" >>"$BACKUP_SIGNAL_RESULT"; exit 143'\'' TERM' \
  '    printf "%s\n" "$name" >"$BACKUP_READY_DIR/$name"' \
  '    while :; do /bin/sleep 1; done' \
  '  fi' \
  '  case "$name" in' \
  '    thaw) printf "%s\n" "${THAW_OUTCOME:-completed}" >"$DOTFILES_BACKUP_OUTCOME_FILE" ;;' \
  '    raycast) printf "%s\n" "${RAYCAST_OUTCOME:-completed}" >"$DOTFILES_BACKUP_OUTCOME_FILE" ;;' \
  '  esac' \
  'fi' \
  'case "$name" in' \
  '  thaw) exit "${THAW_STATUS:-0}" ;;' \
  '  raycast) exit "${RAYCAST_STATUS:-0}" ;;' \
  'esac' \
  >"$FAKE_BIN/fake-backup"
chmod +x "$FAKE_BIN/fake-backup"
ln -s fake-backup "$FAKE_BIN/thaw-config"
ln -s fake-backup "$FAKE_BIN/raycast-config"

: >"$TMP_DIR/direct.log"
set +e
PATH="$FAKE_BIN:/usr/bin:/bin" BACKUP_LOG="$TMP_DIR/direct.log" THAW_STATUS=23 \
  "$FIXTURE_ROOT/dotfiles" backup thaw >"$TMP_DIR/thaw.out" 2>"$TMP_DIR/thaw.err"
thaw_status=$?
set -e
[[ "$thaw_status" -eq 23 ]] || fail "direct Thaw Backup changed child status"
[[ "$(<"$TMP_DIR/thaw.out")" == 'thaw stdout' ]] || fail "direct Thaw Backup changed stdout"
[[ "$(<"$TMP_DIR/thaw.err")" == 'thaw stderr' ]] || fail "direct Thaw Backup changed stderr"
[[ "$(<"$TMP_DIR/direct.log")" == 'thaw backup' ]] || fail "direct Thaw Backup changed arguments"

set +e
PATH="$FAKE_BIN:/usr/bin:/bin" BACKUP_LOG="$TMP_DIR/direct.log" RAYCAST_STATUS=29 \
  "$FIXTURE_ROOT/dotfiles" backup raycast >"$TMP_DIR/raycast.out" 2>"$TMP_DIR/raycast.err"
raycast_status=$?
set -e
[[ "$raycast_status" -eq 29 ]] || fail "direct Raycast Backup changed child status"
[[ "$(<"$TMP_DIR/raycast.out")" == 'raycast stdout' ]] || fail "direct Raycast Backup changed stdout"
[[ "$(<"$TMP_DIR/raycast.err")" == 'raycast stderr' ]] || fail "direct Raycast Backup changed stderr"

started_fifo="$TMP_DIR/started.fifo"
release_dir="$TMP_DIR/release"
mkdir -p "$release_dir"
mkfifo "$started_fifo" "$release_dir/thaw" "$release_dir/raycast"
exec 3<>"$started_fifo"
: >"$TMP_DIR/all.log"

set +e
PATH="$FAKE_BIN:/usr/bin:/bin" \
  BACKUP_LOG="$TMP_DIR/all.log" \
  BACKUP_AGGREGATE=true \
  BACKUP_RELEASE_DIR="$release_dir" \
  THAW_STATUS=0 \
  RAYCAST_STATUS=31 \
  "$FIXTURE_ROOT/dotfiles" backup all >"$TMP_DIR/all.out" 2>"$TMP_DIR/all.err" &
all_pid=$!
set -e

IFS= read -r first_started <&3
IFS= read -r second_started <&3
[[ "$first_started$second_started" == *thaw* && "$first_started$second_started" == *raycast* ]] ||
  fail "aggregate Backup did not start both owners concurrently"
printf 'go\n' >"$release_dir/thaw" &
release_thaw_pid=$!
printf 'go\n' >"$release_dir/raycast" &
release_raycast_pid=$!
wait "$release_thaw_pid" "$release_raycast_pid"

set +e
wait "$all_pid"
all_status=$?
set -e
[[ "$all_status" -eq 1 ]] || fail "aggregate Backup hid a child failure"
thaw_summary_line="$(grep -nF '[backup] thaw: completed' "$TMP_DIR/all.out" | cut -d: -f1)"
raycast_summary_line="$(grep -nF '[backup] raycast: failed (status 31)' "$TMP_DIR/all.out" | cut -d: -f1)"
[[ "$thaw_summary_line" -lt "$raycast_summary_line" ]] || fail "aggregate Backup summary order is unstable"

exec 3<>"$started_fifo"
mkdir -p "$TMP_DIR/skipped-artifacts"
set +e
PATH="$FAKE_BIN:/usr/bin:/bin" BACKUP_LOG="$TMP_DIR/skipped.log" BACKUP_AGGREGATE=true \
  BACKUP_ARTIFACT_DIR="$TMP_DIR/skipped-artifacts" THAW_OUTCOME=skipped RAYCAST_OUTCOME=completed \
  "$FIXTURE_ROOT/dotfiles" backup all >"$TMP_DIR/skipped.out" 2>"$TMP_DIR/skipped.err"
skipped_status=$?
set -e
[[ "$skipped_status" -eq 0 ]] || fail "valid skipped outcome failed aggregate Backup"
grep -qF '[backup] thaw: skipped' "$TMP_DIR/skipped.out" || fail "skipped outcome was not preserved"
[[ -f "$TMP_DIR/skipped-artifacts/raycast" ]] || fail "successful sibling artifact was not preserved"

set +e
PATH="$FAKE_BIN:/usr/bin:/bin" BACKUP_LOG="$TMP_DIR/double.log" BACKUP_AGGREGATE=true \
  THAW_STATUS=41 RAYCAST_STATUS=42 \
  "$FIXTURE_ROOT/dotfiles" backup all >"$TMP_DIR/double.out" 2>"$TMP_DIR/double.err"
double_status=$?
set -e
[[ "$double_status" -eq 1 ]] || fail "double failure did not fail aggregate Backup"
grep -qF '[backup] thaw: failed (status 41)' "$TMP_DIR/double.out" || fail "Thaw double failure is missing"
grep -qF '[backup] raycast: failed (status 42)' "$TMP_DIR/double.out" || fail "Raycast double failure is missing"

signal_tmp="$TMP_DIR/signal-tmp"
signal_ready="$TMP_DIR/signal-ready"
signal_result="$TMP_DIR/signal-result"
mkdir -p "$signal_tmp" "$signal_ready"
: >"$signal_result"
PATH="$FAKE_BIN:/usr/bin:/bin" BACKUP_LOG="$TMP_DIR/signal.log" BACKUP_AGGREGATE=true \
  BACKUP_SIGNAL_FIXTURE=true BACKUP_READY_DIR="$signal_ready" BACKUP_SIGNAL_RESULT="$signal_result" \
  TMPDIR="$signal_tmp" \
  "$FIXTURE_ROOT/dotfiles" backup all >"$TMP_DIR/signal.out" 2>"$TMP_DIR/signal.err" &
signal_coordinator_pid=$!
while [[ ! -f "$signal_ready/thaw" || ! -f "$signal_ready/raycast" ]]; do :; done
kill -TERM "$signal_coordinator_pid"
set +e
wait "$signal_coordinator_pid"
signal_status=$?
set -e
[[ "$signal_status" -eq 143 ]] || fail "aggregate Backup did not preserve TERM status"
grep -qF thaw "$signal_result" || fail "aggregate Backup did not forward TERM to Thaw"
grep -qF raycast "$signal_result" || fail "aggregate Backup did not forward TERM to Raycast"
if find "$signal_tmp" -maxdepth 1 -type d -name 'dotfiles-backup.*' | grep -q .; then
  fail "aggregate Backup left coordinator temporary state after interruption"
fi

mv "$FAKE_BIN/raycast-config" "$TMP_DIR/raycast-config-away"
: >"$TMP_DIR/preflight.log"
set +e
PATH="$FAKE_BIN:/usr/bin:/bin" BACKUP_LOG="$TMP_DIR/preflight.log" \
  "$FIXTURE_ROOT/dotfiles" backup all >"$TMP_DIR/preflight.out" 2>"$TMP_DIR/preflight.err"
preflight_status=$?
set -e
[[ "$preflight_status" -eq 1 ]] || fail "aggregate Backup missing owner did not fail"
[[ ! -s "$TMP_DIR/preflight.log" ]] || fail "aggregate Backup launched a sibling before preflight completed"
