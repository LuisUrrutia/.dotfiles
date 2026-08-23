#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by the fake command.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'pre-commit test: %s\n' "$*" >&2
  exit 1
}

set +e
PATH=/usr/bin:/bin /bin/bash "$ROOT_DIR/.githooks/pre-commit" \
  >"$TMP_DIR/missing.out" 2>"$TMP_DIR/missing.err"
missing_status=$?
set -e
[[ "$missing_status" -eq 1 ]] || fail "missing gitleaks did not block the commit"
grep -F 'gitleaks is required' "$TMP_DIR/missing.err" >/dev/null ||
  fail "missing gitleaks did not explain the prerequisite"

mkdir -p "$TMP_DIR/bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >"$GITLEAKS_TEST_LOG"' \
  'exit "${GITLEAKS_TEST_STATUS:-0}"' \
  >"$TMP_DIR/bin/gitleaks"
chmod +x "$TMP_DIR/bin/gitleaks"

GITLEAKS_TEST_LOG="$TMP_DIR/gitleaks.log" \
  PATH="$TMP_DIR/bin:/usr/bin:/bin" \
  /bin/bash "$ROOT_DIR/.githooks/pre-commit"
[[ "$(<"$TMP_DIR/gitleaks.log")" == 'git --staged --redact --no-banner' ]] ||
  fail "pre-commit did not scan the staged Git state"

set +e
GITLEAKS_TEST_LOG="$TMP_DIR/gitleaks-failed.log" GITLEAKS_TEST_STATUS=9 \
  PATH="$TMP_DIR/bin:/usr/bin:/bin" \
  /bin/bash "$ROOT_DIR/.githooks/pre-commit"
failed_status=$?
set -e
[[ "$failed_status" -eq 9 ]] || fail "gitleaks failure status was not preserved"
