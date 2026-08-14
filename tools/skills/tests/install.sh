#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"
SKILLS_INSTALL="$ROOT_DIR/tools/skills/install.sh"
FAKE_HOMEBREW_BIN="$TMP_DIR/homebrew/bin"
FAKE_MISE_LOG="$TMP_DIR/mise.log"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$FAKE_HOMEBREW_BIN"

cat >"$FAKE_HOMEBREW_BIN/mise" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

log_file="$FAKE_MISE_LOG"

if [[ "$*" == 'which skills' || "$*" == 'which playwright-cli' ]]; then
  exit 0
fi

if [[ "$*" == 'exec -- skills add '* || "$*" == 'exec -- playwright-cli install '* ]]; then
  printf '%s\n' "$*" >>"$log_file"
  exit 0
fi

printf 'Unexpected mise invocation: %s\n' "$*" >&2
exit 1
EOF

chmod +x "$FAKE_HOMEBREW_BIN/mise"

export DOTFILES="$ROOT_DIR"
export HOMEBREW_PREFIX="$TMP_DIR/homebrew"
export FAKE_MISE_LOG
export PATH="/usr/bin:/bin"

bash "$SKILLS_INSTALL" >/dev/null

[[ -s "$FAKE_MISE_LOG" ]]

[[ "$(wc -l <"$FAKE_MISE_LOG")" -eq 8 ]]
grep -F -- 'exec -- skills add ' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill skill-creator' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill vercel-composition-patterns' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill vercel-react-best-practices' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill vercel-react-view-transitions' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill web-design-guidelines' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill grill-with-docs' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill ast-grep' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill commit' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill orca-cli' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--agent opencode --agent claude-code -g -y' "$FAKE_MISE_LOG" >/dev/null
[[ "$(grep -Fxc -- 'exec -- playwright-cli install --skills --global' "$FAKE_MISE_LOG")" -eq 1 ]]
[[ "$(grep -Fxc -- 'exec -- playwright-cli install --skills=agents --global' "$FAKE_MISE_LOG")" -eq 1 ]]

cat >"$FAKE_HOMEBREW_BIN/mise" <<'EOF'
#!/usr/bin/env bash

exit 1
EOF

chmod +x "$FAKE_HOMEBREW_BIN/mise"

missing_skills_output="$TMP_DIR/missing-skills.log"
bash "$SKILLS_INSTALL" >"$TMP_DIR/missing-skills.out" 2>"$missing_skills_output"

grep -F -- 'Warning: skills is not installed by mise, skipping' "$missing_skills_output" >/dev/null
grep -F -- 'Warning: playwright-cli is not installed by mise, skipping' "$missing_skills_output" >/dev/null

rm "$FAKE_HOMEBREW_BIN/mise"
missing_output="$TMP_DIR/missing-mise.log"
bash "$SKILLS_INSTALL" >"$TMP_DIR/missing-mise.out" 2>"$missing_output"

grep -F -- 'Warning: mise not found, skipping' "$missing_output" >/dev/null
