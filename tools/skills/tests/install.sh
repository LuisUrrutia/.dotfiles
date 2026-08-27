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
[[ -s "$FAKE_MISE_LOG" ]]

[[ "$(wc -l <"$FAKE_MISE_LOG")" -eq 8 ]]
grep -F -- 'exec -- skills add ' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill skill-creator' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill ast-grep' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill commit' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--skill orca-cli' "$FAKE_MISE_LOG" >/dev/null
grep -F -- '--agent opencode --agent claude-code -g -y' "$FAKE_MISE_LOG" >/dev/null
[[ "$(grep -Fxc -- 'exec -- playwright-cli install --skills --global' "$FAKE_MISE_LOG")" -eq 1 ]]
[[ "$(grep -Fxc -- 'exec -- playwright-cli install --skills=agents --global' "$FAKE_MISE_LOG")" -eq 1 ]]

vercel_skills_line="$(grep -F -- 'exec -- skills add https://github.com/vercel-labs/agent-skills ' "$FAKE_MISE_LOG")"
vercel_skill_count="$(awk '{ count = 0; for (field = 1; field <= NF; field++) if ($field == "--skill") count++; print count }' <<<"$vercel_skills_line")"
[[ "$vercel_skill_count" -eq 5 ]]

for skill_name in \
  vercel-composition-patterns vercel-react-best-practices \
  vercel-react-view-transitions web-design-guidelines writing-guidelines; do
  [[ " $vercel_skills_line " == *" --skill $skill_name "* ]]
done

[[ " $vercel_skills_line " != *' --skill vercel-react-native-skills '* ]]

matt_skills_line="$(grep -F -- 'exec -- skills add git@github.com:mattpocock/skills.git ' "$FAKE_MISE_LOG")"
matt_skill_count="$(awk '{ count = 0; for (field = 1; field <= NF; field++) if ($field == "--skill") count++; print count }' <<<"$matt_skills_line")"
[[ "$matt_skill_count" -eq 24 ]]

for skill_name in \
  grill-with-docs triage improve-codebase-architecture \
  setup-matt-pocock-skills to-spec to-tickets implement wayfinder prototype \
  diagnosing-bugs research tdd domain-modeling codebase-design code-review \
  resolving-merge-conflicts wizard grill-me handoff teach to-questionnaire \
  wait-what grilling writing-for-agents; do
  [[ " $matt_skills_line " == *" --skill $skill_name "* ]]
done

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
