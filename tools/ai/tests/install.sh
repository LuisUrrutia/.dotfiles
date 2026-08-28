#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
AI_INSTALL="$ROOT_DIR/tools/ai/install.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'ai install test: %s\n' "$*" >&2
  exit 1
}

common_home="$TMP_DIR/common-home"
mkdir -p "$common_home"

HOME="$common_home" \
  DOTFILES="$ROOT_DIR" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$AI_INSTALL" >"$TMP_DIR/common.out" 2>"$TMP_DIR/common.err"

[[ -L "$common_home/.agents/AGENTS.md" ]] || fail "common instructions were not linked"
[[ "$(readlink "$common_home/.agents/AGENTS.md")" == "$ROOT_DIR/tools/ai/AGENTS.md" ]] ||
  fail "common instructions point to the wrong source"
[[ -L "$common_home/.agents/references" ]] || fail "agent references were not linked"
[[ "$(readlink "$common_home/.agents/references")" == "$ROOT_DIR/tools/ai/references" ]] ||
  fail "agent references point to the wrong source"
[[ -f "$common_home/.agents/references/orca.md" ]] || fail "Orca reference is unavailable"
[[ -f "$common_home/.agents/references/orca-session.md" ]] ||
  fail "Orca session reference is unavailable"
[[ -L "$common_home/.codex/AGENTS.md" ]] || fail "Codex instructions were not linked"
[[ "$(readlink "$common_home/.codex/AGENTS.md")" == "$common_home/.agents/AGENTS.md" ]] ||
  fail "Codex instructions do not point to the common destination"
[[ ! -e "$common_home/.agents/AGENTS_LOCAL.md" && ! -L "$common_home/.agents/AGENTS_LOCAL.md" ]] ||
  fail "unregistered machine received local instructions"

grep -F '.agents/AGENTS_LOCAL.md' "$ROOT_DIR/tools/ai/AGENTS.md" >/dev/null ||
  fail "common instructions do not load the optional machine layer"
grep -F 'repository-registration preflight' "$ROOT_DIR/tools/ai/AGENTS.md" >/dev/null ||
  fail "common instructions do not require the Orca repository preflight"
grep -F 'operating from a different checkout' "$ROOT_DIR/tools/ai/AGENTS.md" >/dev/null ||
  fail "common instructions do not route cross-checkout work through Orca handoff"

orca_session="$ROOT_DIR/tools/ai/references/orca-session.md"
ownership_line="$(grep -nF 'The starting agent owns only the checkout path' "$orca_session" |
  head -n 1 | cut -d: -f1)"
grep -F 'newly cloned or imported main checkout' "$orca_session" >/dev/null ||
  fail "Orca session instructions exclude imported main checkouts from handoff"
repo_list_line="$(grep -nF 'orca repo list --json' "$orca_session" | head -n 1 | cut -d: -f1)"
repo_add_line="$(grep -nF 'orca repo add --path <main-worktree-path> --json' "$orca_session" |
  head -n 1 | cut -d: -f1)"
existing_branch_line="$(grep -nF 'wt switch <branch>' "$orca_session" |
  head -n 1 | cut -d: -f1)"
pull_request_line="$(grep -nF 'wt switch pr:<number>' "$orca_session" |
  head -n 1 | cut -d: -f1)"
worktree_create_line="$(grep -nF 'wt switch --create <name>' "$orca_session" |
  head -n 1 | cut -d: -f1)"
terminal_create_line="$(grep -nF 'orca terminal create --worktree path:<abs-path>' "$orca_session" |
  head -n 1 | cut -d: -f1)"
[[ "$ownership_line" -lt "$repo_list_line" ]] ||
  fail "Orca session instructions register a repository before defining checkout ownership"
[[ "$repo_list_line" -lt "$existing_branch_line" &&
  "$repo_add_line" -lt "$existing_branch_line" &&
  "$repo_list_line" -lt "$pull_request_line" &&
  "$repo_add_line" -lt "$pull_request_line" &&
  "$repo_list_line" -lt "$worktree_create_line" &&
  "$repo_add_line" -lt "$worktree_create_line" ]] ||
  fail "Orca session instructions resolve a destination before registering its repository"
[[ "$existing_branch_line" -lt "$terminal_create_line" &&
  "$pull_request_line" -lt "$terminal_create_line" &&
  "$worktree_create_line" -lt "$terminal_create_line" ]] ||
  fail "Orca session instructions launch an agent before resolving its destination"
[[ "$(<"$ROOT_DIR/tools/claude/config/.claude/CLAUDE.md")" == '@~/.agents/AGENTS.md' ]] ||
  fail "Claude does not import the common instructions"

fixture_root="$TMP_DIR/repository"
fixture_home="$TMP_DIR/registered-home"
mkdir -p "$fixture_root/tools/ai/references" "$fixture_root/machines" "$fixture_home"
cp "$AI_INSTALL" "$fixture_root/tools/ai/install.sh"
cp "$ROOT_DIR/tools/ai/AGENTS.md" "$fixture_root/tools/ai/AGENTS.md"
cp "$ROOT_DIR/tools/ai/references/orca.md" "$fixture_root/tools/ai/references/orca.md"
cp "$ROOT_DIR/tools/ai/references/orca-session.md" \
  "$fixture_root/tools/ai/references/orca-session.md"
cp "$ROOT_DIR/tools/lib.sh" "$fixture_root/tools/lib.sh"
printf '%s\n' 'MACHINE_ID="fixture"' >"$fixture_root/machines/registered.sh"
printf '%s\n' '# Registered machine instructions' >"$fixture_root/machines/registered.agents.md"

HOME="$fixture_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=registered \
  /bin/bash "$fixture_root/tools/ai/install.sh" >/dev/null

[[ -L "$fixture_home/.agents/AGENTS_LOCAL.md" ]] || fail "registered machine lacks local instructions"
[[ "$(readlink "$fixture_home/.agents/AGENTS_LOCAL.md")" == "$fixture_root/machines/registered.agents.md" ]] ||
  fail "registered machine local link points to the wrong source"

rm "$fixture_root/machines/registered.agents.md"
HOME="$fixture_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=registered \
  /bin/bash "$fixture_root/tools/ai/install.sh" >/dev/null
[[ ! -e "$fixture_home/.agents/AGENTS_LOCAL.md" && ! -L "$fixture_home/.agents/AGENTS_LOCAL.md" ]] ||
  fail "known stale local instructions were not removed"

unregistered_home="$TMP_DIR/unregistered-source-home"
mkdir -p "$unregistered_home"
printf '%s\n' '# Source without Machine Config' >"$fixture_root/machines/source-only.agents.md"
HOME="$unregistered_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=source-only \
  /bin/bash "$fixture_root/tools/ai/install.sh" >/dev/null
[[ ! -e "$unregistered_home/.agents/AGENTS_LOCAL.md" ]] ||
  fail "source without Machine Config registered the machine"

conflict_home="$TMP_DIR/conflict-home"
mkdir -p "$conflict_home/.agents"
printf '%s\n' 'foreign common instructions' >"$conflict_home/.agents/AGENTS.md"
set +e
HOME="$conflict_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" \
  >"$TMP_DIR/conflict.out" 2>"$TMP_DIR/conflict.err"
conflict_status=$?
set -e
[[ "$conflict_status" -eq 1 ]] || fail "regular instruction conflict did not fail"
[[ "$(<"$conflict_home/.agents/AGENTS.md")" == 'foreign common instructions' ]] ||
  fail "regular instruction conflict was overwritten"
[[ ! -e "$conflict_home/.codex/AGENTS.md" ]] || fail "conflict caused partial installation"

references_conflict_home="$TMP_DIR/references-conflict-home"
mkdir -p "$references_conflict_home/.agents/references"
printf '%s\n' 'local reference' >"$references_conflict_home/.agents/references/local.md"
set +e
HOME="$references_conflict_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" \
  >"$TMP_DIR/references-conflict.out" 2>"$TMP_DIR/references-conflict.err"
references_conflict_status=$?
set -e
[[ "$references_conflict_status" -eq 1 ]] || fail "regular references conflict did not fail"
[[ -d "$references_conflict_home/.agents/references" && ! -L "$references_conflict_home/.agents/references" ]] ||
  fail "regular references directory was replaced"
[[ "$(<"$references_conflict_home/.agents/references/local.md")" == 'local reference' ]] ||
  fail "local reference was modified"
[[ ! -e "$references_conflict_home/.agents/AGENTS.md" ]] ||
  fail "references conflict caused partial common installation"
[[ ! -e "$references_conflict_home/.codex/AGENTS.md" ]] ||
  fail "references conflict caused partial Codex installation"

foreign_references_home="$TMP_DIR/foreign-references-home"
foreign_references_source="$TMP_DIR/foreign-references"
mkdir -p "$foreign_references_home/.agents" "$foreign_references_source"
ln -s "$foreign_references_source" "$foreign_references_home/.agents/references"
set +e
HOME="$foreign_references_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" \
  >"$TMP_DIR/foreign-references.out" 2>"$TMP_DIR/foreign-references.err"
foreign_references_status=$?
set -e
[[ "$foreign_references_status" -eq 1 ]] || fail "foreign references symlink did not fail"
[[ "$(readlink "$foreign_references_home/.agents/references")" == "$foreign_references_source" ]] ||
  fail "foreign references symlink was replaced"
[[ ! -e "$foreign_references_home/.agents/AGENTS.md" ]] ||
  fail "foreign references conflict caused partial installation"

foreign_home="$TMP_DIR/foreign-home"
mkdir -p "$foreign_home/.agents"
ln -s "$TMP_DIR/foreign-agents.md" "$foreign_home/.agents/AGENTS_LOCAL.md"
set +e
HOME="$foreign_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" \
  >"$TMP_DIR/foreign.out" 2>"$TMP_DIR/foreign.err"
foreign_status=$?
set -e
[[ "$foreign_status" -eq 1 ]] || fail "foreign local symlink did not fail"
[[ "$(readlink "$foreign_home/.agents/AGENTS_LOCAL.md")" == "$TMP_DIR/foreign-agents.md" ]] ||
  fail "foreign local symlink was replaced"
[[ ! -e "$foreign_home/.agents/AGENTS.md" ]] || fail "foreign conflict caused partial installation"

traversal_home="$TMP_DIR/traversal-home"
mkdir -p "$traversal_home/.agents"
ln -s "$traversal_home/.dotfiles/machines/../../foreign.agents.md" \
  "$traversal_home/.agents/AGENTS_LOCAL.md"
set +e
HOME="$traversal_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" \
  >"$TMP_DIR/traversal.out" 2>"$TMP_DIR/traversal.err"
traversal_status=$?
set -e
[[ "$traversal_status" -eq 1 ]] || fail "machine instruction traversal symlink did not fail"
[[ "$(readlink "$traversal_home/.agents/AGENTS_LOCAL.md")" == \
  "$traversal_home/.dotfiles/machines/../../foreign.agents.md" ]] ||
  fail "machine instruction traversal symlink was replaced"
[[ ! -e "$traversal_home/.agents/AGENTS.md" ]] || fail "traversal conflict caused partial installation"

foreign_common_home="$TMP_DIR/foreign-common-home"
mkdir -p "$foreign_common_home/.agents" "$TMP_DIR/foreign-repository/tools/ai"
ln -s "$TMP_DIR/foreign-repository/tools/ai/AGENTS.md" \
  "$foreign_common_home/.agents/AGENTS.md"
set +e
HOME="$foreign_common_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" \
  >"$TMP_DIR/foreign-common.out" 2>"$TMP_DIR/foreign-common.err"
foreign_common_status=$?
set -e
[[ "$foreign_common_status" -eq 1 ]] || fail "foreign common suffix symlink did not fail"
[[ "$(readlink "$foreign_common_home/.agents/AGENTS.md")" == \
  "$TMP_DIR/foreign-repository/tools/ai/AGENTS.md" ]] ||
  fail "foreign common suffix symlink was replaced"
[[ ! -e "$foreign_common_home/.codex/AGENTS.md" ]] ||
  fail "foreign common conflict caused partial installation"

repair_home="$TMP_DIR/repair-home"
mkdir -p "$repair_home/.agents"
ln -s "$repair_home/.dotfiles/tools/ai/AGENTS.md" "$repair_home/.agents/AGENTS.md"
HOME="$repair_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" >/dev/null
[[ "$(readlink "$repair_home/.agents/AGENTS.md")" == "$fixture_root/tools/ai/AGENTS.md" ]] ||
  fail "known broken common link was not repaired"

references_repair_home="$TMP_DIR/references-repair-home"
mkdir -p "$references_repair_home/.agents"
ln -s "$references_repair_home/.dotfiles/tools/ai/references" \
  "$references_repair_home/.agents/references"
HOME="$references_repair_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" >/dev/null
[[ "$(readlink "$references_repair_home/.agents/references")" == "$fixture_root/tools/ai/references" ]] ||
  fail "known broken references link was not repaired"

canonical_home="$TMP_DIR/canonical-home"
mkdir -p "$canonical_home/.agents" "$canonical_home/.codex"
ln -s "$fixture_root/tools/ai/../ai/AGENTS.md" "$canonical_home/.agents/AGENTS.md"
ln -s "$fixture_root/tools/ai/../ai/references" "$canonical_home/.agents/references"
ln -s "../.agents/AGENTS.md" "$canonical_home/.codex/AGENTS.md"
HOME="$canonical_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" >/dev/null
[[ "$(readlink "$canonical_home/.agents/AGENTS.md")" == "$fixture_root/tools/ai/AGENTS.md" ]] ||
  fail "equivalent common link was not normalized to the canonical source"
[[ "$(readlink "$canonical_home/.agents/references")" == "$fixture_root/tools/ai/references" ]] ||
  fail "equivalent references link was not normalized to the canonical source"
[[ "$(readlink "$canonical_home/.codex/AGENTS.md")" == "$canonical_home/.agents/AGENTS.md" ]] ||
  fail "equivalent Codex link was not normalized to the canonical source"

hash_failure_home="$TMP_DIR/hash-failure-home"
mkdir -p "$hash_failure_home"
HOME="$hash_failure_home" DOTFILES="$fixture_root" \
  /bin/bash "$fixture_root/tools/ai/install.sh" \
  >"$TMP_DIR/hash-failure.out" 2>"$TMP_DIR/hash-failure.err" ||
  fail "hardware-hash failure blocked common agent instructions"
grep -F 'could not determine the hardware hash' "$TMP_DIR/hash-failure.err" >/dev/null ||
  fail "hardware-hash failure did not emit a warning"
[[ -L "$hash_failure_home/.agents/AGENTS.md" && -L "$hash_failure_home/.codex/AGENTS.md" ]] ||
  fail "hardware-hash failure skipped common agent instructions"
[[ ! -e "$hash_failure_home/.agents/AGENTS_LOCAL.md" ]] ||
  fail "hardware-hash failure installed machine-local instructions"

override_home="$TMP_DIR/override-home"
mkdir -p "$override_home/.codex"
printf '%s\n' '# Local override' >"$override_home/.codex/AGENTS.override.md"
HOME="$override_home" \
  DOTFILES="$fixture_root" \
  DOTFILES_HARDWARE_HASH_OVERRIDE=unregistered \
  /bin/bash "$fixture_root/tools/ai/install.sh" \
  >"$TMP_DIR/override.out" 2>"$TMP_DIR/override.err"
grep -F 'shadows the managed global Codex instructions' "$TMP_DIR/override.err" >/dev/null ||
  fail "non-empty Codex override did not warn"
[[ "$(<"$override_home/.codex/AGENTS.override.md")" == '# Local override' ]] ||
  fail "Codex override was modified"
