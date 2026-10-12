#!/usr/bin/env bash

set -euo pipefail

repo_path="${1:-}"
pr_number="${2:-}"

if [[ "$#" -ne 2 || ! -d "$repo_path" || ! "$pr_number" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Usage: review-pr.sh <repository-path> <pull-request-number>\n' >&2
  exit 2
fi

for prerequisite in wt jq t3code; do
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

review_prompt="Use the pr-review skill to review pull request #$pr_number against its base. Invoke \$pr-review in Codex or /pr-review in Claude Code. If the skill is unavailable, stop and report that it needs to be installed. Do not modify the worktree. Report findings with file and line references."
exec t3code handover --cwd "$review_path" --checkout current --open desktop \
  --mode plan --permission approval-required --prompt "$review_prompt" </dev/null
