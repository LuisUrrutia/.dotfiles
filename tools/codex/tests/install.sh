#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CODEX_INSTALL="$ROOT_DIR/tools/codex/install.sh"
TMP_DIR="$(mktemp -d)"
FAKE_HOMEBREW_BIN="$TMP_DIR/homebrew/bin"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  echo "codex install test: $*" >&2
  exit 1
}

mkdir -p "$FAKE_HOMEBREW_BIN"

cat >"$FAKE_HOMEBREW_BIN/mise" <<'EOF'
#!/usr/bin/env bash

[[ "$*" == "which codex" ]]
EOF
chmod +x "$FAKE_HOMEBREW_BIN/mise"

run_installer() {
  local fixture_home="$1"

  HOME="$fixture_home" \
    DOTFILES="$ROOT_DIR" \
    HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
    PATH="$FAKE_HOMEBREW_BIN:/usr/bin:/bin" \
    /bin/bash "$CODEX_INSTALL"
}

existing_home="$TMP_DIR/existing-home"
mkdir -p "$existing_home/.codex"
cat >"$existing_home/.codex/config.toml" <<'EOF'
model = "gpt-5.6-sol"
personality = "friendly"
model_reasoning_effort = "medium"
plan_mode_reasoning_effort = "high"
web_search = "cached"

[skills]
max_context_tokens = 5000

[[skills.config]]
name = "unused"
enabled = false

[features]
memories = true
EOF

run_installer "$existing_home" >"$TMP_DIR/existing.out"
grep -F 'personality = "pragmatic"' "$existing_home/.codex/config.toml" >/dev/null ||
  fail "personality was not updated"
grep -F 'model_reasoning_effort = "xhigh"' "$existing_home/.codex/config.toml" >/dev/null ||
  fail "model reasoning effort was not updated"
grep -F 'plan_mode_reasoning_effort = "xhigh"' "$existing_home/.codex/config.toml" >/dev/null ||
  fail "plan-mode reasoning effort was not updated"
grep -F 'web_search = "live"' "$existing_home/.codex/config.toml" >/dev/null ||
  fail "web search mode was not updated"
grep -F 'max_context_tokens = 10000' "$existing_home/.codex/config.toml" >/dev/null ||
  fail "existing skills budget was not updated"
[[ "$(grep -Fc 'max_context_tokens =' "$existing_home/.codex/config.toml")" -eq 1 ]] ||
  fail "existing skills budget was duplicated"
grep -F 'name = "unused"' "$existing_home/.codex/config.toml" >/dev/null ||
  fail "skills enablement state was not preserved"
grep -F 'memories = false' "$existing_home/.codex/config.toml" >/dev/null ||
  fail "memories were not disabled"

backup="$(find "$existing_home/.codex" -maxdepth 1 -type f -name 'config.toml.local-backup.*' -print)"
[[ -n "$backup" ]] || fail "existing config was not backed up"
grep -F 'max_context_tokens = 5000' "$backup" >/dev/null ||
  fail "backup does not contain the previous config"
grep -F 'memories = true' "$backup" >/dev/null ||
  fail "backup does not contain the previous memories setting"

run_installer "$existing_home" >"$TMP_DIR/existing-second.out"
[[ "$(find "$existing_home/.codex" -maxdepth 1 -type f -name 'config.toml.local-backup.*' | wc -l)" -eq 1 ]] ||
  fail "idempotent install created another backup"
grep -F 'already configured' "$TMP_DIR/existing-second.out" >/dev/null ||
  fail "idempotent install did not report its state"

missing_table_home="$TMP_DIR/missing-table-home"
mkdir -p "$missing_table_home/.codex"
printf '%s\n' 'model = "gpt-5.6-sol"' >"$missing_table_home/.codex/config.toml"
run_installer "$missing_table_home" >/dev/null
grep -F '[skills]' "$missing_table_home/.codex/config.toml" >/dev/null ||
  fail "missing skills table was not added"
grep -F 'max_context_tokens = 10000' "$missing_table_home/.codex/config.toml" >/dev/null ||
  fail "missing skills budget was not added"
grep -F '[features]' "$missing_table_home/.codex/config.toml" >/dev/null ||
  fail "missing features table was not added"
grep -F 'memories = false' "$missing_table_home/.codex/config.toml" >/dev/null ||
  fail "missing memories setting was not added"
grep -F 'personality = "pragmatic"' "$missing_table_home/.codex/config.toml" >/dev/null ||
  fail "missing top-level settings were not added"

empty_home="$TMP_DIR/empty-home"
mkdir -p "$empty_home/.codex"
: >"$empty_home/.codex/config.toml"
run_installer "$empty_home" >/dev/null
cmp -s "$ROOT_DIR/tools/codex/settings.toml" "$empty_home/.codex/config.toml" ||
  fail "empty config was not populated with the managed settings"

duplicate_home="$TMP_DIR/duplicate-home"
mkdir -p "$duplicate_home/.codex"
cat >"$duplicate_home/.codex/config.toml" <<'EOF'
[features]
memories = true
memories = false
EOF
if run_installer "$duplicate_home" >"$TMP_DIR/duplicate.out" 2>"$TMP_DIR/duplicate.err"; then
  fail "duplicate managed setting was accepted"
fi
grep -F 'refusing duplicate Codex setting: features.memories' "$TMP_DIR/duplicate.err" >/dev/null ||
  fail "duplicate managed setting refusal was not explained"
grep -F 'memories = true' "$duplicate_home/.codex/config.toml" >/dev/null ||
  fail "ambiguous config was modified"

new_home="$TMP_DIR/new-home"
run_installer "$new_home" >/dev/null
cmp -s "$ROOT_DIR/tools/codex/settings.toml" "$new_home/.codex/config.toml" ||
  fail "new config does not match the managed settings"
[[ "$(stat -f '%Lp' "$new_home/.codex/config.toml")" == 600 ]] ||
  fail "new config permissions are not private"

symlink_home="$TMP_DIR/symlink-home"
mkdir -p "$symlink_home/.codex" "$TMP_DIR/foreign"
printf '%s\n' 'foreign = true' >"$TMP_DIR/foreign/config.toml"
ln -s "$TMP_DIR/foreign/config.toml" "$symlink_home/.codex/config.toml"
if run_installer "$symlink_home" >"$TMP_DIR/symlink.out" 2>"$TMP_DIR/symlink.err"; then
  fail "foreign config symlink was accepted"
fi
grep -F 'refusing unowned Codex config symlink' "$TMP_DIR/symlink.err" >/dev/null ||
  fail "foreign config symlink refusal was not explained"
grep -F 'foreign = true' "$TMP_DIR/foreign/config.toml" >/dev/null ||
  fail "foreign config symlink target was modified"

cat >"$FAKE_HOMEBREW_BIN/mise" <<'EOF'
#!/usr/bin/env bash

exit 1
EOF
chmod +x "$FAKE_HOMEBREW_BIN/mise"

missing_codex_home="$TMP_DIR/missing-codex-home"
run_installer "$missing_codex_home" >"$TMP_DIR/missing-codex.out" 2>"$TMP_DIR/missing-codex.err"
grep -F 'codex is not installed by mise, skipping' "$TMP_DIR/missing-codex.err" >/dev/null ||
  fail "missing Codex warning was not emitted"
[[ ! -e "$missing_codex_home/.codex/config.toml" ]] ||
  fail "config was written without the mise-owned Codex CLI"

echo "codex install test: passed"
