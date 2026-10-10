#!/usr/bin/env bash

set -euo pipefail

repo_path="${1:-}"
pr_number="${2:-}"

if [[ "$#" -ne 2 || ! -d "$repo_path" || ! "$pr_number" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Usage: review-pr.sh <repository-path> <pull-request-number>\n' >&2
  exit 2
fi

for prerequisite in wt jq tmux codex claude; do
  if ! command -v "$prerequisite" >/dev/null 2>&1; then
    printf 'gh-dash review: required command is unavailable: %s\n' "$prerequisite" >&2
    exit 1
  fi
done

worktree_json="$(wt -C "$repo_path" switch "pr:$pr_number" --no-cd --format json -y)"
review_path="$(printf '%s\n' "$worktree_json" | jq -er '.path | strings | select(length > 0)')" || {
  printf 'gh-dash review: WorkTrunk did not return the pull-request worktree path\n' >&2
  exit 1
}

codex_prompt="Use the code-review skill to review pull request #$pr_number. Do not modify the worktree. Report findings with file and line references."
claude_prompt="Review pull request #$pr_number against its base. Do not modify the worktree. Report findings with file and line references."
printf -v codex_command 'exec codex %q' "$codex_prompt"
printf -v claude_command 'exec claude --agent code-reviewer %q' "$claude_prompt"

window_id="$(tmux new-window -P -F '#{window_id}' -c "$review_path" \
  -n "PR-$pr_number-review" "$codex_command")"
tmux split-window -h -t "$window_id" -c "$review_path" "$claude_command"
tmux select-layout -t "$window_id" even-horizontal >/dev/null
