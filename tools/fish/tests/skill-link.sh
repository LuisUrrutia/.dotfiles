#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FUNCTION_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/functions/skill-link.fish"
COMPLETION_FILE="$DOTFILES_ROOT/tools/fish/config/.config/fish/completions/skill-link.fish"
# Physical path: skill-link resolves its argument, and macOS puts the temporary
# directory behind the /var -> /private/var symlink.
TMP_DIR="$(cd "$(mktemp -d)" && pwd -P)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'skill-link test: %s\n' "$*" >&2
  exit 1
}

[[ -f "$FUNCTION_FILE" ]] || fail "the function is missing"
[[ -f "$COMPLETION_FILE" ]] || fail "the completion is missing"

FAKE_HOME="$TMP_DIR/home"
PROJECT_DIR="$TMP_DIR/projects"
AGENTS_SKILLS="$FAKE_HOME/.agents/skills"
CLAUDE_SKILLS="$FAKE_HOME/.claude/skills"
BACKUPS="$FAKE_HOME/.agents/skills-backups"

mkdir -p "$FAKE_HOME"

# Run skill-link in an isolated HOME. --no-config keeps the operator's own Fish
# configuration out of the run.
run_skill_link() {
  HOME="$FAKE_HOME" FUNCTION_FILE="$FUNCTION_FILE" fish --no-config -c \
    "source \"\$FUNCTION_FILE\"; cd \"$1\"; skill-link $2"
}

write_skill() {
  mkdir -p "$1/references"
  printf '%s\n' "$2" >"$1/SKILL.md"
  printf 'reference\n' >"$1/references/one.md"
}

count_backups() {
  find "$BACKUPS" -mindepth 2 -maxdepth 2 2>/dev/null | wc -l | tr -d ' '
}

# Arrange: a skill directory, plus tool state the comparison must ignore.
write_skill "$PROJECT_DIR/skills/pr" 'pr v2'
mkdir -p "$PROJECT_DIR/skills/pr/.omo"
printf 'tool state\n' >"$PROJECT_DIR/skills/pr/.omo/state.json"

# Arrange: an installed copy that matches, and one that drifted.
mkdir -p "$AGENTS_SKILLS/pr/references" "$CLAUDE_SKILLS/pr/evals"
printf 'pr v2\n' >"$AGENTS_SKILLS/pr/SKILL.md"
printf 'reference\n' >"$AGENTS_SKILLS/pr/references/one.md"
printf 'pr v1 with local edits\n' >"$CLAUDE_SKILLS/pr/SKILL.md"
printf 'eval\n' >"$CLAUDE_SKILLS/pr/evals/one.md"

# Act: link by absolute path, with the trailing slash a shell would add.
run_skill_link "$TMP_DIR" "$PROJECT_DIR/skills/pr/" >"$TMP_DIR/link.out" 2>&1 ||
  fail "linking by path failed: $(<"$TMP_DIR/link.out")"

# Assert: both agent directories point at the source directory itself.
[[ "$(readlink "$AGENTS_SKILLS/pr")" == "$PROJECT_DIR/skills/pr" ]] ||
  fail "pr is not linked in .agents"
[[ "$(readlink "$CLAUDE_SKILLS/pr")" == "$PROJECT_DIR/skills/pr" ]] ||
  fail "pr is not linked in .claude"

# Assert: the identical copy was discarded, the drifted one was preserved.
[[ ! -e "$BACKUPS/agents" ]] || fail "an identical installed copy was backed up"
drifted="$(find "$BACKUPS/claude" -maxdepth 1 -name 'pr-*' | head -1)"
[[ -n "$drifted" ]] || fail "a drifted installed copy was not backed up"
[[ "$(<"$drifted/SKILL.md")" == 'pr v1 with local edits' ]] ||
  fail "the backup lost the drifted SKILL.md"
[[ -f "$drifted/evals/one.md" ]] || fail "the backup lost the drifted evals"

# Act: relinking is idempotent and adds no backups.
run_skill_link "$TMP_DIR" "$PROJECT_DIR/skills/pr" >"$TMP_DIR/relink.out" 2>&1 ||
  fail "relinking failed"
grep -q 'Already linked' "$TMP_DIR/relink.out" || fail "relinking did not report a no-op"
[[ "$(count_backups)" -eq 1 ]] || fail "relinking created another backup"

# Act: a skill with no installed copy links from the directory it stands in.
write_skill "$PROJECT_DIR/skills/oc-killer" 'oc-killer v1'
run_skill_link "$PROJECT_DIR/skills/oc-killer" . >"$TMP_DIR/cwd.out" 2>&1 ||
  fail "linking the current directory failed: $(<"$TMP_DIR/cwd.out")"
[[ "$(readlink "$AGENTS_SKILLS/oc-killer")" == "$PROJECT_DIR/skills/oc-killer" ]] ||
  fail "oc-killer is not linked in .agents"
[[ "$(readlink "$CLAUDE_SKILLS/oc-killer")" == "$PROJECT_DIR/skills/oc-killer" ]] ||
  fail "oc-killer is not linked in .claude"

# Act: no argument means the current directory.
write_skill "$PROJECT_DIR/skills/walkthrough" 'walkthrough v1'
run_skill_link "$PROJECT_DIR/skills/walkthrough" "" >/dev/null 2>&1 ||
  fail "linking without an argument failed"
[[ "$(readlink "$AGENTS_SKILLS/walkthrough")" == "$PROJECT_DIR/skills/walkthrough" ]] ||
  fail "the default directory was not linked"

# Assert: a directory without a SKILL.md is refused.
mkdir -p "$PROJECT_DIR/skills/docs"
printf 'docs\n' >"$PROJECT_DIR/skills/docs/README.md"
if run_skill_link "$TMP_DIR" "$PROJECT_DIR/skills/docs" >"$TMP_DIR/nodoc.out" 2>&1; then
  fail "a directory without SKILL.md was accepted"
fi
grep -q 'no SKILL.md' "$TMP_DIR/nodoc.out" || fail "the SKILL.md refusal is not explained"
[[ ! -e "$AGENTS_SKILLS/docs" ]] || fail "a directory without SKILL.md was linked"

# Assert: a missing directory is refused.
if run_skill_link "$TMP_DIR" "$PROJECT_DIR/skills/nowhere" >/dev/null 2>&1; then
  fail "a missing directory was accepted"
fi
[[ ! -e "$AGENTS_SKILLS/nowhere" ]] || fail "a missing directory created a link"

# Assert: an installed skill directory cannot be linked onto itself.
write_skill "$AGENTS_SKILLS/installed-only" 'installed only'
if run_skill_link "$TMP_DIR" "$AGENTS_SKILLS/installed-only" >"$TMP_DIR/self.out" 2>&1; then
  fail "an installed skill was accepted as a source"
fi
[[ -f "$AGENTS_SKILLS/installed-only/SKILL.md" ]] ||
  fail "the refused self-link damaged the installed skill"
grep -q 'already an installed skill' "$TMP_DIR/self.out" ||
  fail "the self-link refusal is not explained"

# Assert: a link the skills CLI chained between agent directories is replaced.
rm "$CLAUDE_SKILLS/walkthrough"
ln -s "$AGENTS_SKILLS/walkthrough" "$CLAUDE_SKILLS/walkthrough"
run_skill_link "$TMP_DIR" "$PROJECT_DIR/skills/walkthrough" >/dev/null 2>&1 ||
  fail "relinking a chained symlink failed"
[[ "$(readlink "$CLAUDE_SKILLS/walkthrough")" == "$PROJECT_DIR/skills/walkthrough" ]] ||
  fail "a chained symlink was not repointed at the source"
[[ "$(count_backups)" -eq 1 ]] || fail "replacing a chained symlink created a backup"

# Assert: a symlink nobody here manages is preserved, not deleted.
foreign="$TMP_DIR/foreign/oc-killer"
write_skill "$foreign" 'someone else'
rm "$CLAUDE_SKILLS/oc-killer"
ln -s "$foreign" "$CLAUDE_SKILLS/oc-killer"
run_skill_link "$TMP_DIR" "$PROJECT_DIR/skills/oc-killer" >/dev/null 2>&1 ||
  fail "relinking over a foreign symlink failed"
[[ "$(readlink "$CLAUDE_SKILLS/oc-killer")" == "$PROJECT_DIR/skills/oc-killer" ]] ||
  fail "the foreign symlink was not replaced"
preserved="$(find "$BACKUPS/claude" -maxdepth 1 -name 'oc-killer-*' | head -1)"
[[ -n "$preserved" ]] || fail "a foreign symlink was deleted instead of preserved"
[[ -L "$preserved" ]] || fail "the preserved foreign symlink is no longer a symlink"
[[ "$(readlink "$preserved")" == "$foreign" ]] || fail "the preserved symlink lost its target"

# Assert: an unknown option is refused.
if run_skill_link "$TMP_DIR" "--bogus" >/dev/null 2>&1; then
  fail "an unknown option was accepted"
fi

printf 'skill-link test: ok\n'
