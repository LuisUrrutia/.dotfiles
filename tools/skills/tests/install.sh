#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"
SKILLS_INSTALL="$ROOT_DIR/tools/skills/install.sh"
FAKE_BIN_DIR="$TMP_DIR/bin"
FAKE_NPX_LOG="$TMP_DIR/npx.log"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$FAKE_BIN_DIR"

cat >"$FAKE_BIN_DIR/npx" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

log_file="$FAKE_NPX_LOG"

if [[ "$*" == *'skills@latest add'* ]]; then
  printf '%s\n' "$*" >>"$log_file"
  exit 0
fi

printf 'Unexpected npx invocation: %s\n' "$*" >&2
exit 1
EOF

chmod +x "$FAKE_BIN_DIR/npx"

export DOTFILES="$ROOT_DIR"
export HOMEBREW_PREFIX="$TMP_DIR/homebrew"
export FAKE_NPX_LOG
export PATH="$FAKE_BIN_DIR:/usr/bin:/bin"

bash "$SKILLS_INSTALL" >/dev/null

[[ -s "$FAKE_NPX_LOG" ]]

[[ "$(wc -l <"$FAKE_NPX_LOG")" -eq 5 ]]
grep -F -- '--skill skill-creator' "$FAKE_NPX_LOG" >/dev/null
grep -F -- '--skill vercel-composition-patterns' "$FAKE_NPX_LOG" >/dev/null
grep -F -- '--skill vercel-react-best-practices' "$FAKE_NPX_LOG" >/dev/null
grep -F -- '--skill vercel-react-view-transitions' "$FAKE_NPX_LOG" >/dev/null
grep -F -- '--skill web-design-guidelines' "$FAKE_NPX_LOG" >/dev/null
grep -F -- '--skill grill-with-docs' "$FAKE_NPX_LOG" >/dev/null
grep -F -- '--skill ast-grep' "$FAKE_NPX_LOG" >/dev/null
grep -F -- '--skill commit' "$FAKE_NPX_LOG" >/dev/null
grep -F -- '--agent opencode --agent claude-code -g -y' "$FAKE_NPX_LOG" >/dev/null

missing_output="$TMP_DIR/missing-npx.log"
PATH="/usr/bin:/bin" bash "$SKILLS_INSTALL" >"$TMP_DIR/missing-npx.out" 2>"$missing_output"

grep -F -- 'Warning: npx not found, skipping global skills' "$missing_output" >/dev/null
