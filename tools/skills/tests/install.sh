#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"
SKILLS_INSTALL="$ROOT_DIR/tools/skills/install.sh"
FAKE_HOMEBREW_BIN="$TMP_DIR/homebrew/bin"
FAKE_MISE_LOG="$TMP_DIR/mise.log"
FAKE_STOW_LOG="$TMP_DIR/stow.log"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$FAKE_HOMEBREW_BIN"

cat >"$FAKE_HOMEBREW_BIN/stow" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

printf '%s\n' "$*" >>"$FAKE_STOW_LOG"
EOF

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

chmod +x "$FAKE_HOMEBREW_BIN/mise" "$FAKE_HOMEBREW_BIN/stow"

export DOTFILES="$ROOT_DIR"
export HOMEBREW_PREFIX="$TMP_DIR/homebrew"
export FAKE_MISE_LOG
export FAKE_STOW_LOG
export HOME="$TMP_DIR/home"
export PATH="$FAKE_HOMEBREW_BIN:/usr/bin:/bin"

mkdir -p "$HOME"

bash "$SKILLS_INSTALL" >/dev/null

grep -F -- "--restow --no-folding -d $ROOT_DIR/tools/skills -t $HOME config" "$FAKE_STOW_LOG" >/dev/null
diff -u - "$FAKE_MISE_LOG" <<'EOF'
exec -- skills add git@github.com:anthropics/skills.git --skill frontend-design --agent opencode --agent claude-code -g -y
exec -- skills add git@github.com:vercel-labs/agent-skills.git --skill vercel-react-best-practices vercel-composition-patterns --agent opencode --agent claude-code -g -y
exec -- skills add git@github.com:addyosmani/agent-skills.git --skill performance-optimization --agent opencode --agent claude-code -g -y
exec -- skills add git@github.com:kitlangton/2password.git --skill 2password --agent opencode --agent claude-code -g -y
exec -- skills add git@github.com:tester-army/e2e.git --skill e2e --agent opencode --agent claude-code -g -y
exec -- skills add git@github.com:LuisUrrutia/skills.git --skill comment-style communicate-clearly --agent opencode --agent claude-code -g -y
exec -- playwright-cli install --skills --global
exec -- playwright-cli install --skills=agents --global
EOF

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
[[ "$(wc -l <"$FAKE_STOW_LOG")" -eq 3 ]]
