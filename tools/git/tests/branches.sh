#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$ROOT_DIR/tools/git/config/.config/git/local.gitconfig"
export GIT_TERMINAL_PROMPT=0
export PATH="$ROOT_DIR/tools/git/config/.local/bin:$PATH"
mkdir -p "$HOME"

setup_repo() {
  REPO="$TMP_ROOT/$1"
  git init -q -b main "$REPO"
  cd "$REPO"
  git config user.name 'Test User'
  git config user.email test@example.com
  git config commit.gpgsign false
  git config core.hooksPath /dev/null
  git commit -q --allow-empty -m 'Initial commit'
}

assert_fails() {
  if "$@" >"$TMP_ROOT/out" 2>"$TMP_ROOT/err"; then
    printf 'Expected failure: %s\n' "$*" >&2
    return 1
  fi
  [[ -s "$TMP_ROOT/err" ]]
}

test_recent_invalid_ref() {
  setup_repo invalid-ref
  assert_fails git recent-branches missing-ref
  [[ ! -s "$TMP_ROOT/out" ]]
}

test_recent_invalid_count() {
  setup_repo invalid-count
  assert_fails git recent-branches HEAD oops
  assert_fails git recent-branches HEAD -1
  assert_fails git recent-branches HEAD 20 extra
}

test_dm_invalid_ref() {
  setup_repo dm-invalid-ref
  assert_fails git dm missing-ref
  assert_fails git dm HEAD extra
}

test_recent_counts_and_plain_output() {
  setup_repo counts
  git branch behind
  git checkout -q -b topic
  git commit -q --allow-empty -m 'Topic | with delimiter'
  git checkout -q main
  git commit -q --allow-empty -m 'Main change'

  git recent-branches HEAD 20 >"$TMP_ROOT/out"

  [[ "$(cat "$TMP_ROOT/out")" != *$'\033['* ]]
  awk '$1 == 0 && $2 == 0 && $3 == "*main" {found=1} END {exit !found}' "$TMP_ROOT/out"
  awk '$1 == 0 && $2 == 1 && $3 == "behind" {found=1} END {exit !found}' "$TMP_ROOT/out"
  awk '$1 == 1 && $2 == 1 && $3 == "topic" {found=1} END {exit !found}' "$TMP_ROOT/out"
  grep -F 'Topic | with delimiter' "$TMP_ROOT/out" >/dev/null
  [[ "$(git recent-branches HEAD 1 | wc -l | tr -d ' ')" == 2 ]]
}

test_recent_default_comparison() {
  setup_repo defaults
  git remote add origin git@example.com:example/repo.git
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git checkout -q -b topic
  git commit -q --allow-empty -m Topic
  git update-ref refs/remotes/origin/topic HEAD
  git branch --set-upstream-to=origin/topic >/dev/null

  git recent-branches >"$TMP_ROOT/out"

  awk '$1 == 1 && $2 == 0 && $3 == "*topic" {found=1} END {exit !found}' "$TMP_ROOT/out"
  git symbolic-ref --delete refs/remotes/origin/HEAD
  git recent-branches >"$TMP_ROOT/out"
  awk '$1 == 0 && $2 == 0 && $3 == "*topic" {found=1} END {exit !found}' "$TMP_ROOT/out"
  git branch --unset-upstream
  git recent-branches >"$TMP_ROOT/out"
  awk '$1 == 0 && $2 == 0 && $3 == "*topic" {found=1} END {exit !found}' "$TMP_ROOT/out"
}

test_recent_color_override() {
  setup_repo color
  [[ "$(git recent-branches --color=always HEAD)" == *$'\033['* ]]
  [[ "$(git recent-branches --color=never HEAD)" != *$'\033['* ]]
  assert_fails git recent-branches --color=invalid HEAD
}

test_recent_batches_git_queries() {
  setup_repo batched
  local i=0
  for ((i = 0; i < 20; i++)); do
    git branch "topic-$i"
  done

  GIT_TRACE="$TMP_ROOT/trace" git recent-branches HEAD 20 >/dev/null

  if grep -qF 'built-in: git rev-list' "$TMP_ROOT/trace"; then
    echo 'recent-branches still traverses history per branch' >&2
    return 1
  fi
  [[ "$(grep -c 'built-in: git for-each-ref' "$TMP_ROOT/trace")" == 1 ]]
}

test_dm_preserves_current_and_protected_branches() {
  setup_repo delete-merged
  git branch merged
  git branch develop
  git branch master
  git branch dev
  git checkout -q -b current

  git dm >"$TMP_ROOT/out"

  if git show-ref --verify --quiet refs/heads/merged; then
    echo 'Merged branch was not deleted' >&2
    return 1
  fi
  local branch=""
  for branch in main master develop dev current; do
    git show-ref --verify --quiet "refs/heads/$branch"
  done
  git dm >/dev/null
}

test_dm_reports_deletion_failure() {
  setup_repo deletion-failure
  git checkout -q -b upstream
  git commit -q --allow-empty -m Upstream
  git checkout -q main
  git branch a-merged
  git branch z-merged
  git config branch.a-merged.remote .
  git config branch.a-merged.merge refs/heads/upstream
  git checkout -q a-merged
  git commit -q --allow-empty -m 'Not merged upstream'
  git checkout -q main
  git merge --ff-only a-merged >/dev/null

  assert_fails git dm

  git show-ref --verify --quiet refs/heads/a-merged
  if git show-ref --verify --quiet refs/heads/z-merged; then
    echo 'Deletion stopped before processing the remaining branch' >&2
    return 1
  fi
}

tests=(
  test_recent_invalid_ref test_recent_invalid_count test_dm_invalid_ref
  test_recent_counts_and_plain_output test_recent_default_comparison
  test_recent_color_override test_recent_batches_git_queries
  test_dm_preserves_current_and_protected_branches test_dm_reports_deletion_failure
)
if (($# > 0)); then
  tests=("$@")
fi
for test_name in "${tests[@]}"; do
  "$test_name"
  printf 'ok %s\n' "$test_name"
done
