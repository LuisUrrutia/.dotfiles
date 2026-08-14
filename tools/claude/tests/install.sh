#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLAUDE_INSTALL="$ROOT_DIR/tools/claude/install.sh"
TMP_DIR="$(mktemp -d)"
FAKE_BIN="$TMP_DIR/homebrew/bin"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'claude install test: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$FAKE_BIN" "$TMP_DIR/home"

cat >"$FAKE_BIN/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == which && "${2:-}" == claude ]] || exit 1
[[ "${CLAUDE_MISSING:-false}" != true ]]
EOF

cat >"$FAKE_BIN/stow" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$STOW_LOG"
EOF

chmod +x "$FAKE_BIN/mise" "$FAKE_BIN/stow"
export STOW_LOG="$TMP_DIR/stow.log"

HOME="$TMP_DIR/home" \
  DOTFILES="$ROOT_DIR" \
  HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
  PATH="$FAKE_BIN:/usr/bin:/bin" \
  /bin/bash "$CLAUDE_INSTALL" >/dev/null

grep -F -- "--restow --no-folding -d $ROOT_DIR/tools/claude" "$STOW_LOG" >/dev/null ||
  fail "Claude config was not stowed after mise ownership was verified"

before_count="$(wc -l <"$STOW_LOG")"
CLAUDE_MISSING=true \
  HOME="$TMP_DIR/home" \
  DOTFILES="$ROOT_DIR" \
  HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
  PATH="$FAKE_BIN:/usr/bin:/bin" \
  /bin/bash "$CLAUDE_INSTALL" >"$TMP_DIR/missing.out" 2>"$TMP_DIR/missing.err"

grep -F 'claude is not installed by mise, skipping' "$TMP_DIR/missing.err" >/dev/null ||
  fail "missing mise-owned Claude command did not produce a warning"
[[ "$(wc -l <"$STOW_LOG")" -eq "$before_count" ]] ||
  fail "Claude config was stowed without its mise-owned command"

printf 'claude install test: passed\n'
