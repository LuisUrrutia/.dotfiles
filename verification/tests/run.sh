#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by fixture shells.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_RUNNER="$ROOT_DIR/verification/run.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'verification test: %s\n' "$*" >&2
  exit 1
}

[[ -x "$VERIFY_RUNNER" ]] || fail "Verification Runner is not executable"

fixture="$TMP_DIR/fixture"
mkdir -p "$fixture/groups"
printf '%s\n' missing-verifier-one missing-verifier-two >"$fixture/requirements"

for group in workflow security shell bootstrap lua fish brewfiles stow dispatcher; do
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "$0" >>"$VERIFY_STARTED_LOG"' \
    >"$fixture/groups/$group.sh"
  chmod +x "$fixture/groups/$group.sh"
done

set +e
PATH=/usr/bin:/bin \
  DOTFILES_VERIFICATION_FIXTURE="$fixture" \
  VERIFY_STARTED_LOG="$TMP_DIR/preflight-started.log" \
  "$ROOT_DIR/dotfiles" verify \
  >"$TMP_DIR/preflight.out" 2>"$TMP_DIR/preflight.err"
preflight_status=$?
set -e

[[ "$preflight_status" -eq 1 ]] || fail "missing prerequisites did not fail Verification"
grep -F 'missing-verifier-one' "$TMP_DIR/preflight.err" >/dev/null ||
  fail "preflight omitted the first missing prerequisite"
grep -F 'missing-verifier-two' "$TMP_DIR/preflight.err" >/dev/null ||
  fail "preflight omitted the second missing prerequisite"
[[ ! -e "$TMP_DIR/preflight-started.log" ]] || fail "preflight failure started a group"

fake_bin="$TMP_DIR/bin"
runtime_dir="$TMP_DIR/runtime"
mkdir -p "$fake_bin" "$runtime_dir"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$fake_bin/fixture-verifier"
chmod +x "$fake_bin/fixture-verifier"
printf '%s\n' fixture-verifier >"$fixture/requirements"

for group in workflow security shell bootstrap lua fish brewfiles stow dispatcher; do
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'name="$(basename "$0" .sh)"' \
    'printf "%s\n" "$name" >>"$VERIFY_STARTED_LOG"' \
    'while [[ ! -e "$VERIFY_RELEASE" ]]; do /bin/sleep 0.02; done' \
    'printf "%s output\n" "$name"' \
    'if [[ "${VERIFY_SCENARIO:-}" == security-fails && "$name" == security ]]; then exit 7; fi' \
    >"$fixture/groups/$group.sh"
  chmod +x "$fixture/groups/$group.sh"
done

started_log="$TMP_DIR/started.log"
release_file="$TMP_DIR/release"

set +e
PATH="$fake_bin:/usr/bin:/bin" \
  TMPDIR="$runtime_dir" \
  DOTFILES_VERIFICATION_FIXTURE="$fixture" \
  VERIFY_STARTED_LOG="$started_log" \
  VERIFY_RELEASE="$release_file" \
  VERIFY_SCENARIO=security-fails \
  "$ROOT_DIR/dotfiles" verify \
  >"$TMP_DIR/groups.out" 2>"$TMP_DIR/groups.err" &
verify_pid=$!
set -e

started_count=0
attempt=0
while [[ "$attempt" -lt 200 ]]; do
  if [[ -f "$started_log" ]]; then
    started_count="$(wc -l <"$started_log" | tr -d ' ')"
  fi
  [[ "$started_count" -ge 4 ]] && break
  /bin/sleep 0.02
  attempt=$((attempt + 1))
done

if [[ "$started_count" -ne 4 ]]; then
  cat "$TMP_DIR/groups.err" >&2
  fail "Verification did not start exactly four initial workers"
fi
/bin/sleep 0.05
[[ "$(wc -l <"$started_log" | tr -d ' ')" -eq 4 ]] || fail "Verification exceeded four workers"
touch "$release_file"

set +e
wait "$verify_pid"
groups_status=$?
set -e

[[ "$groups_status" -eq 1 ]] || fail "offline group failure did not fail Verification"
[[ "$(sort -u "$started_log" | wc -l | tr -d ' ')" -eq 9 ]] || fail "Verification did not continue every group"
grep -F 'security output' "$TMP_DIR/groups.out" >/dev/null || fail "failed group log was not replayed"

workflow_line="$(grep -nF '[verify] workflow: passed' "$TMP_DIR/groups.out" | cut -d: -f1)"
security_line="$(grep -nF '[verify] security: failed' "$TMP_DIR/groups.out" | cut -d: -f1)"
shell_line="$(grep -nF '[verify] shell: passed' "$TMP_DIR/groups.out" | cut -d: -f1)"
[[ "$workflow_line" -lt "$security_line" && "$security_line" -lt "$shell_line" ]] ||
  fail "Verification results were not rendered in stable group order"
[[ -z "$(find "$runtime_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]] ||
  fail "Verification left temporary runtime state"

rm "$started_log" "$release_file"
touch "$release_file"
PATH="$fake_bin:/usr/bin:/bin" \
  TMPDIR="$runtime_dir" \
  DOTFILES_VERIFICATION_FIXTURE="$fixture" \
  VERIFY_STARTED_LOG="$started_log" \
  VERIFY_RELEASE="$release_file" \
  VERIFY_SCENARIO=all-pass \
  "$ROOT_DIR/dotfiles" verify \
  >"$TMP_DIR/success.out" 2>"$TMP_DIR/success.err"

grep -F '[verify] dispatcher: passed' "$TMP_DIR/success.out" >/dev/null ||
  fail "successful Verification omitted the final group result"

rm -f "$release_file"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  "trap '/bin/sleep 0.2; printf \"%s\\\\n\" stopped >\"\$VERIFY_CHILD_STOPPED\"; exit 143' TERM" \
  'printf "%s\n" ready >"$VERIFY_SIGNAL_READY"' \
  'while :; do /bin/sleep 1; done' \
  >"$fixture/signal-child.sh"
chmod +x "$fixture/signal-child.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'trap "exit 143" TERM' \
  '/bin/bash "$VERIFY_SIGNAL_CHILD" &' \
  'wait "$!"' \
  >"$fixture/groups/workflow.sh"
chmod +x "$fixture/groups/workflow.sh"

PATH="$fake_bin:/usr/bin:/bin" \
  TMPDIR="$runtime_dir" \
  DOTFILES_VERIFICATION_FIXTURE="$fixture" \
  VERIFY_STARTED_LOG="$started_log" \
  VERIFY_RELEASE="$release_file" \
  VERIFY_SIGNAL_CHILD="$fixture/signal-child.sh" \
  VERIFY_SIGNAL_READY="$TMP_DIR/signal-ready" \
  VERIFY_CHILD_STOPPED="$TMP_DIR/child-stopped" \
  "$ROOT_DIR/dotfiles" verify \
  >"$TMP_DIR/signal.out" 2>"$TMP_DIR/signal.err" &
signal_pid=$!

attempt=0
while [[ "$attempt" -lt 200 && ! -e "$TMP_DIR/signal-ready" ]]; do
  /bin/sleep 0.02
  attempt=$((attempt + 1))
done
[[ -e "$TMP_DIR/signal-ready" ]] || fail "signal fixture did not start its descendant"

kill -TERM "$signal_pid"
set +e
wait "$signal_pid"
signal_status=$?
set -e
[[ "$signal_status" -eq 143 ]] || fail "Verification did not preserve TERM status"
[[ -e "$TMP_DIR/child-stopped" ]] || fail "Verification did not signal a group descendant"
[[ -z "$(find "$runtime_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]] ||
  fail "interrupted Verification left temporary runtime state"
