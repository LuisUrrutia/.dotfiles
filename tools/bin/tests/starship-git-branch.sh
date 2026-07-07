#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT_DIR/tools/bin/config/.local/bin/starship-git-branch"
TMP_DIR="$(mktemp -d)"
GLYPH=$'\356\202\240'

# Isolate from the user's git configuration (signing, hooks, templates).
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.com"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

make_repo() {
  local dir="$1"
  local branch="$2"

  mkdir -p "$dir"
  git -C "$dir" init -q -b "$branch"
  git -C "$dir" commit -q --allow-empty -m 'initial'
}

assert_output() {
  local dir="$1"
  local expected="$2"
  local actual=""

  actual="$(cd "$dir" && "$SCRIPT")"
  [[ "$actual" == "$expected" ]]
}

assert_hidden() {
  local dir="$1"

  if (cd "$dir" && "$SCRIPT"); then
    printf 'expected no output for %s\n' "$dir" >&2
    return 1
  fi
}

test_shows_current_branch() {
  local dir="$TMP_DIR/project"

  make_repo "$dir" feature-x
  assert_output "$dir" "$GLYPH feature-x"
}

test_detached_head_shows_short_sha() {
  local dir="$TMP_DIR/detached"
  local sha=""

  make_repo "$dir" main
  git -C "$dir" checkout -q --detach
  sha="$(git -C "$dir" rev-parse --short HEAD)"
  assert_output "$dir" "$GLYPH @$sha"
}

test_hides_branch_when_worktree_dir_matches() {
  local dir="$TMP_DIR/project.fix-bug"

  make_repo "$dir" fix-bug
  assert_hidden "$dir"
}

test_hides_branch_when_worktree_dir_matches_leaf() {
  local dir="$TMP_DIR/project.login"

  make_repo "$dir" feat/login
  assert_hidden "$dir"
}

test_shows_branch_in_subdirectory_of_worktree() {
  local dir="$TMP_DIR/plain-repo"

  make_repo "$dir" my-branch
  mkdir -p "$dir/src/deep"
  assert_output "$dir/src/deep" "$GLYPH my-branch"
}

test_unborn_branch_shows_branch_name() {
  local dir="$TMP_DIR/fresh"

  mkdir -p "$dir"
  git -C "$dir" init -q -b brand-new
  assert_output "$dir" "$GLYPH brand-new"
}

test_outside_repo_prints_nothing() {
  local dir="$TMP_DIR/not-a-repo"

  mkdir -p "$dir"
  assert_hidden "$dir"
}

tests=(
  test_shows_current_branch
  test_detached_head_shows_short_sha
  test_hides_branch_when_worktree_dir_matches
  test_hides_branch_when_worktree_dir_matches_leaf
  test_shows_branch_in_subdirectory_of_worktree
  test_unborn_branch_shows_branch_name
  test_outside_repo_prints_nothing
)

for test_name in "${tests[@]}"; do
  "$test_name"
  printf 'ok %s\n' "$test_name"
done
