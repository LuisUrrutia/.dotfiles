#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by fake commands.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
REVIEW_SCRIPT="$ROOT_DIR/tools/gh-dash/review-pr.sh"
TMP_DIR="$(mktemp -d)"
FAKE_BIN="$TMP_DIR/bin"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'gh-dash review test: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$FAKE_BIN" "$TMP_DIR/repository" "$TMP_DIR/review worktree"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >"$WT_TEST_LOG"' \
  'printf '\''{"action":"switched","branch":"fixture","path":"%s"}\n'\'' "$REVIEW_WORKTREE"' \
  >"$FAKE_BIN/wt"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >>"$TMUX_TEST_LOG"' \
  '[[ "${1:-}" != new-window ]] || printf "%s\n" @17' \
  >"$FAKE_BIN/tmux"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$FAKE_BIN/codex"
cp "$FAKE_BIN/codex" "$FAKE_BIN/claude"
chmod +x "$FAKE_BIN"/*

WT_TEST_LOG="$TMP_DIR/wt.log" TMUX_TEST_LOG="$TMP_DIR/tmux.log" \
  REVIEW_WORKTREE="$TMP_DIR/review worktree" \
  PATH="$FAKE_BIN:/opt/homebrew/bin:/usr/bin:/bin" \
  "$REVIEW_SCRIPT" "$TMP_DIR/repository" 42

grep -F -- "-C $TMP_DIR/repository switch pr:42 --no-cd --format json -y" \
  "$TMP_DIR/wt.log" >/dev/null || fail "review did not resolve the PR through WorkTrunk"
grep -F 'new-window' "$TMP_DIR/tmux.log" | grep -F 'exec codex' >/dev/null ||
  fail "review did not open the Codex pane"
grep -F 'split-window' "$TMP_DIR/tmux.log" | grep -F 'exec claude --agent code-reviewer' >/dev/null ||
  fail "review did not open the Claude reviewer pane"
[[ "$(grep -Fc "$TMP_DIR/review worktree" "$TMP_DIR/tmux.log")" -eq 2 ]] ||
  fail "review panes did not share the resolved PR worktree"

set +e
PATH="$FAKE_BIN:/opt/homebrew/bin:/usr/bin:/bin" \
  "$REVIEW_SCRIPT" "$TMP_DIR/repository" invalid \
  >"$TMP_DIR/invalid.out" 2>"$TMP_DIR/invalid.err"
invalid_status=$?
set -e
[[ "$invalid_status" -eq 2 ]] || fail "invalid PR number did not return usage status"
