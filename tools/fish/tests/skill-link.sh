#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FUNCTIONS_DIR="$DOTFILES_ROOT/tools/fish/config/.config/fish/functions"
FUNCTION_FILE="$FUNCTIONS_DIR/skill-link.fish"
AGENT_DIRS_FILE="$FUNCTIONS_DIR/skill_agent_dirs.fish"
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
[[ -f "$AGENT_DIRS_FILE" ]] || fail "the agent directory function is missing"
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
  HOME="$FAKE_HOME" FUNCTIONS_DIR="$FUNCTIONS_DIR" fish --no-config -c \
    "set -p fish_function_path \"\$FUNCTIONS_DIR\"; cd \"$1\"; skill-link $2"
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

# Arrange: shell glob expansion includes skills, files, and non-skill directories.
write_skill "$PROJECT_DIR/batch/alpha" 'alpha v1'
write_skill "$PROJECT_DIR/batch/beta" 'beta v1'
mkdir -p "$PROJECT_DIR/batch/docs" "$PROJECT_DIR/batch/not-a-skill/SKILL.md"
printf 'docs\n' >"$PROJECT_DIR/batch/README.md"
write_skill "$PROJECT_DIR/batch/container/nested-skill" 'nested v1'

# Act: Fish expands the wildcard before calling skill-link.
run_skill_link "$PROJECT_DIR/batch" "*" >"$TMP_DIR/batch.out" 2>&1 ||
  fail "linking a wildcard batch failed: $(<"$TMP_DIR/batch.out")"

# Assert: every expanded skill directory was linked.
for skill in alpha beta; do
  [[ "$(readlink "$AGENTS_SKILLS/$skill")" == "$PROJECT_DIR/batch/$skill" ]] ||
    fail "$skill is not linked in .agents"
  [[ "$(readlink "$CLAUDE_SKILLS/$skill")" == "$PROJECT_DIR/batch/$skill" ]] ||
    fail "$skill is not linked in .claude"
done

for agent_dir in "$AGENTS_SKILLS" "$CLAUDE_SKILLS"; do
  for entry in docs not-a-skill README.md container nested-skill; do
    [[ ! -e "$agent_dir/$entry" && ! -L "$agent_dir/$entry" ]] ||
      fail "a non-skill or nested skill was linked: $agent_dir/$entry"
  done
done

# Arrange: an explicit list includes a non-skill and a nested path with spaces.
mkdir -p "$PROJECT_DIR/partial/a-docs"
printf 'docs\n' >"$PROJECT_DIR/partial/a-docs/README.md"
write_skill "$PROJECT_DIR/partial/nested/z valid" 'valid v1'

# Act: trailing slashes and quoted paths work while non-skills are skipped.
run_skill_link "$PROJECT_DIR/partial" "a-docs/ 'nested/z valid/'" >"$TMP_DIR/partial.out" 2>&1 ||
  fail "linking a mixed directory list failed: $(<"$TMP_DIR/partial.out")"

# Assert: both agents receive only the valid skill.
for agent_dir in "$AGENTS_SKILLS" "$CLAUDE_SKILLS"; do
  [[ "$(readlink "$agent_dir/z valid")" == "$PROJECT_DIR/partial/nested/z valid" ]] ||
    fail "the valid skill in a mixed directory list was not linked"
  [[ ! -e "$agent_dir/a-docs" && ! -L "$agent_dir/a-docs" ]] ||
    fail "the non-skill directory in a list was linked"
done
grep -q '^Skipped .*: no SKILL.md' "$TMP_DIR/partial.out" ||
  fail "the skipped directory was not explained"

# Assert: a directory without a SKILL.md is a successful no-op.
mkdir -p "$PROJECT_DIR/skills/docs"
printf 'docs\n' >"$PROJECT_DIR/skills/docs/README.md"
run_skill_link "$TMP_DIR" "$PROJECT_DIR/skills/docs" >"$TMP_DIR/nodoc.out" 2>&1 ||
  fail "skipping a directory without SKILL.md failed"
grep -q '^Skipped .*: no SKILL.md' "$TMP_DIR/nodoc.out" || fail "the skip is not explained"
for agent_dir in "$AGENTS_SKILLS" "$CLAUDE_SKILLS"; do
  [[ ! -e "$agent_dir/docs" && ! -L "$agent_dir/docs" ]] ||
    fail "a directory without SKILL.md was linked"
done

# Assert: a missing directory is refused.
if run_skill_link "$TMP_DIR" "$PROJECT_DIR/skills/nowhere" >/dev/null 2>&1; then
  fail "a missing directory was accepted"
fi
[[ ! -e "$AGENTS_SKILLS/nowhere" ]] || fail "a missing directory created a link"

# Arrange: a missing path precedes a valid skill.
write_skill "$PROJECT_DIR/skills/after-error" 'after-error v1'

# Act: real errors still fail the batch while later skills are processed.
if run_skill_link "$PROJECT_DIR/skills" "nowhere after-error/" >"$TMP_DIR/error.out" 2>&1; then
  fail "a batch containing a missing path succeeded"
fi

for agent_dir in "$AGENTS_SKILLS" "$CLAUDE_SKILLS"; do
  [[ "$(readlink "$agent_dir/after-error")" == "$PROJECT_DIR/skills/after-error" ]] ||
    fail "the valid skill after a missing path was not linked"
done
grep -q 'not a directory' "$TMP_DIR/error.out" || fail "the missing path is not explained"

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
