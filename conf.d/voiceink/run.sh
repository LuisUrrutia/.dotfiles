#!/usr/bin/env bash
set -euo pipefail

: "${VOICEINK_FULL_PROMPT:?VOICEINK_FULL_PROMPT must be set}"
voiceink_dir="$HOME/.local/share/voiceink-codex"

codex_prompt=$(
  for skill_name in comment-style communicate-clearly; do
    skill_file="$voiceink_dir/skills/$skill_name/SKILL.md"
    printf '<skill>\n<name>%s</name>\n<path>%s</path>\n' "$skill_name" "$skill_file"
    cat "$skill_file" || exit 1
    printf '\n</skill>\n\n'
  done
  printf '%s\n' "$VOICEINK_FULL_PROMPT"
)

exec env CODEX_HOME="$voiceink_dir" \
  "$HOME/.local/share/mise/shims/codex" \
  -C "$voiceink_dir" \
  exec --skip-git-repo-check --ephemeral --color never \
  "$codex_prompt" </dev/null
