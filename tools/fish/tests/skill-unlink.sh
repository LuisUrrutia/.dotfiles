#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FUNCTIONS_DIR="$DOTFILES_ROOT/tools/fish/config/.config/fish/functions"
FUNCTION_FILE="$FUNCTIONS_DIR/skill-unlink.fish"
AGENT_DIRS_FILE="$FUNCTIONS_DIR/skill_agent_dirs.fish"
COMPLETION_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/completions/skill-unlink.fish"
# Physical path: skill-unlink resolves its argument, and macOS puts the temporary
# directory behind the /var -> /private/var symlink.
TMP_DIR="$(cd "$(mktemp -d)" && pwd -P)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'skill-unlink test: %s\n' "$*" >&2
  exit 1
}

[[ -f "$FUNCTION_FILE" ]] || fail "the function is missing"
[[ -f "$AGENT_DIRS_FILE" ]] || fail "the agent directory function is missing"
[[ -f "$COMPLETION_FILE" ]] || fail "the completion is missing"

FAKE_HOME="$TMP_DIR/home"
PROJECT_DIR="$TMP_DIR/projects"
AGENTS_SKILLS="$FAKE_HOME/.agents/skills"
CLAUDE_SKILLS="$FAKE_HOME/.claude/skills"

mkdir -p "$FAKE_HOME"

run_skill_unlink() {
  HOME="$FAKE_HOME" FUNCTIONS_DIR="$FUNCTIONS_DIR" fish --no-config -c \
    "set -p fish_function_path \"\$FUNCTIONS_DIR\"; cd \"$1\"; skill-unlink $2"
}

write_skill() {
  mkdir -p "$1"
  printf '%s\n' "$2" >"$1/SKILL.md"
}

# Arrange: both agent paths resolve to the same development directory through
# direct and chained symlinks.
write_skill "$PROJECT_DIR/skills/pr" 'pr v1'
mkdir -p "$AGENTS_SKILLS" "$CLAUDE_SKILLS"
ln -s "$PROJECT_DIR/skills/pr" "$AGENTS_SKILLS/pr"
ln -s "$AGENTS_SKILLS/pr" "$CLAUDE_SKILLS/pr"

# Act: unlink by absolute path.
run_skill_unlink "$TMP_DIR" "$PROJECT_DIR/skills/pr" >"$TMP_DIR/unlink.out" 2>&1 ||
  fail "unlinking by path failed: $(<"$TMP_DIR/unlink.out")"

# Assert: both links were removed without touching their source or parents.
[[ ! -e "$AGENTS_SKILLS/pr" && ! -L "$AGENTS_SKILLS/pr" ]] ||
  fail "the .agents link remains"
[[ ! -e "$CLAUDE_SKILLS/pr" && ! -L "$CLAUDE_SKILLS/pr" ]] ||
  fail "the .claude link remains"
[[ -f "$PROJECT_DIR/skills/pr/SKILL.md" ]] || fail "the source skill was damaged"
[[ -d "$AGENTS_SKILLS" && -d "$CLAUDE_SKILLS" ]] || fail "an agent directory was removed"
[[ "$(grep -c '^Unlinked ' "$TMP_DIR/unlink.out")" -eq 2 ]] ||
  fail "the removed links were not reported"

# Act: unlinking again is an idempotent no-op.
run_skill_unlink "$TMP_DIR" "$PROJECT_DIR/skills/pr" >"$TMP_DIR/reunlink.out" 2>&1 ||
  fail "repeated unlinking failed"

# Assert: both absent links are reported.
[[ "$(grep -c '^Not linked ' "$TMP_DIR/reunlink.out")" -eq 2 ]] ||
  fail "repeated unlinking did not report both no-ops"

# Arrange: the default directory has one matching link and one unrelated link.
write_skill "$PROJECT_DIR/skills/walkthrough" 'walkthrough v1'
write_skill "$PROJECT_DIR/other/walkthrough" 'foreign walkthrough'
ln -s "$PROJECT_DIR/skills/walkthrough" "$AGENTS_SKILLS/walkthrough"
ln -s "$PROJECT_DIR/other/walkthrough" "$CLAUDE_SKILLS/walkthrough"

# Act: no argument means the current directory.
run_skill_unlink "$PROJECT_DIR/skills/walkthrough" "" >"$TMP_DIR/default.out" 2>&1 ||
  fail "unlinking the current directory failed"

# Assert: the matching link was removed and the unrelated one was preserved.
[[ ! -e "$AGENTS_SKILLS/walkthrough" && ! -L "$AGENTS_SKILLS/walkthrough" ]] ||
  fail "the current directory link remains"
[[ -L "$CLAUDE_SKILLS/walkthrough" ]] || fail "an unrelated link was removed"
[[ "$(readlink "$CLAUDE_SKILLS/walkthrough")" == "$PROJECT_DIR/other/walkthrough" ]] ||
  fail "the unrelated link target changed"
grep -q '^Preserved .*: points to ' "$TMP_DIR/default.out" ||
  fail "the preserved unrelated link was not reported"

# Arrange: an installed copy occupies the matching skill name.
write_skill "$PROJECT_DIR/skills/docs" 'development docs'
mkdir -p "$AGENTS_SKILLS/docs"
printf 'installed docs\n' >"$AGENTS_SKILLS/docs/SKILL.md"

# Act: unlink the development directory.
run_skill_unlink "$TMP_DIR" "$PROJECT_DIR/skills/docs" >"$TMP_DIR/installed.out" 2>&1 ||
  fail "preserving an installed copy failed"

# Assert: the installed copy is unchanged.
[[ "$(<"$AGENTS_SKILLS/docs/SKILL.md")" == 'installed docs' ]] ||
  fail "the installed copy was changed"
grep -q '^Preserved .*: not a symlink' "$TMP_DIR/installed.out" ||
  fail "the preserved installed copy was not reported"

# Arrange: multiple development skills are linked in both agent directories.
for skill in alpha beta; do
  write_skill "$PROJECT_DIR/batch/$skill" "$skill v1"
  ln -s "$PROJECT_DIR/batch/$skill" "$AGENTS_SKILLS/$skill"
  ln -s "$PROJECT_DIR/batch/$skill" "$CLAUDE_SKILLS/$skill"
done

# Act: Fish expands the wildcard before calling skill-unlink.
run_skill_unlink "$PROJECT_DIR/batch" "*" >"$TMP_DIR/batch.out" 2>&1 ||
  fail "unlinking a wildcard batch failed: $(<"$TMP_DIR/batch.out")"

# Assert: every matching development link was removed.
for skill in alpha beta; do
  [[ ! -e "$AGENTS_SKILLS/$skill" && ! -L "$AGENTS_SKILLS/$skill" ]] ||
    fail "the .agents $skill link remains"
  [[ ! -e "$CLAUDE_SKILLS/$skill" && ! -L "$CLAUDE_SKILLS/$skill" ]] ||
    fail "the .claude $skill link remains"
done

# Arrange: an invalid file sorts before a valid linked skill.
mkdir -p "$PROJECT_DIR/partial"
printf 'not a directory\n' >"$PROJECT_DIR/partial/a-file"
write_skill "$PROJECT_DIR/partial/z-valid" 'valid v1'
ln -s "$PROJECT_DIR/partial/z-valid" "$AGENTS_SKILLS/z-valid"
ln -s "$PROJECT_DIR/partial/z-valid" "$CLAUDE_SKILLS/z-valid"

# Act: the batch reports failure but continues after the invalid path.
if run_skill_unlink "$PROJECT_DIR/partial" "*" >"$TMP_DIR/partial.out" 2>&1; then
  fail "a partially invalid wildcard batch succeeded"
fi

# Assert: the valid links were still removed.
[[ ! -e "$AGENTS_SKILLS/z-valid" && ! -L "$AGENTS_SKILLS/z-valid" ]] ||
  fail "the valid .agents link after a batch error remains"
[[ ! -e "$CLAUDE_SKILLS/z-valid" && ! -L "$CLAUDE_SKILLS/z-valid" ]] ||
  fail "the valid .claude link after a batch error remains"
grep -q 'not a directory' "$TMP_DIR/partial.out" ||
  fail "the partial batch failure was not explained"

# Assert: invalid arguments are refused.
if run_skill_unlink "$TMP_DIR" "$PROJECT_DIR/skills/nowhere" >/dev/null 2>&1; then
  fail "a missing directory was accepted"
fi
if run_skill_unlink "$TMP_DIR" "--bogus" >/dev/null 2>&1; then
  fail "an unknown option was accepted"
fi

printf 'skill-unlink test: ok\n'
