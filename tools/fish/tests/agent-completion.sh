#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fish expands the environment variables in this snippet.

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FISH="${FISH_BIN:-$(command -v fish)}"
CODEX_COMPLETION="$DOTFILES_ROOT/tools/fish/config/.config/fish/completions/codex.fish"
CLAUDE_COMPLETION="$DOTFILES_ROOT/tools/fish/config/.config/fish/completions/claude.fish"
CLAUDE_CHECK="$DOTFILES_ROOT/tools/fish/check-claude-completion.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'Agent completion test: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/codex" <<'EOF'
#!/usr/bin/env bash

if [[ "$*" == "completion fish" ]]; then
  printf '%s\n' \
    "complete -c codex -l model -r -d 'Select the model'" \
    "complete -c codex -f -a exec -d 'Run Codex non-interactively'"
  exit 0
fi

exit 1
EOF
chmod +x "$TMP_DIR/bin/codex"

cat >"$TMP_DIR/bin/claude" <<'EOF'
#!/usr/bin/env bash

if [[ "$*" == "--help" ]]; then
  cat <<'HELP'
Usage: claude [options] [command]

Options:
  --future-mode <mode>  Select a mode added by a future Claude release
  -h, --help            Display help

Commands:
  launch                Launch a future Claude capability
HELP
  exit 0
fi

exit 1
EOF
chmod +x "$TMP_DIR/bin/claude"

complete_for() {
  local completion="$1"
  local commandline="$2"

  COMPLETION="$completion" TARGET="$commandline" PATH="$TMP_DIR/bin:/opt/homebrew/bin:/usr/bin:/bin" \
    "$FISH" --no-config -c 'source "$COMPLETION"; and complete -C "$TARGET"' </dev/null
}

codex_options="$(complete_for "$CODEX_COMPLETION" 'codex --')"
[[ "$codex_options" == *'--model'* ]] || fail "Codex options were not loaded from its generator"

codex_commands="$(complete_for "$CODEX_COMPLETION" 'codex e')"
[[ "$codex_commands" == *$'exec\t'* ]] || fail "Codex subcommands were not loaded from its generator"

claude_options="$(complete_for "$CLAUDE_COMPLETION" 'claude --future')"
[[ "$claude_options" == *'--future-mode'* ]] || fail "Claude options were not discovered from the installed CLI"

claude_commands="$(complete_for "$CLAUDE_COMPLETION" 'claude lau')"
[[ "$claude_commands" == *$'launch\t'* ]] || fail "Claude subcommands were not discovered from the installed CLI"

claude_documented_options="$(complete_for "$CLAUDE_COMPLETION" 'claude --')"
for documented_option in \
  advisor \
  append-subagent-system-prompt \
  append-system-prompt-file \
  channels \
  dangerously-load-development-channels \
  exec \
  init \
  init-only \
  maintenance \
  max-turns \
  permission-prompt-tool \
  rc \
  ref \
  remote \
  system-prompt-file \
  teammate-mode; do
  [[ "$claude_documented_options" == *"--$documented_option"* ]] ||
    fail "Documented Claude option omitted from --help is absent: --$documented_option"
done

CLAUDE_BIN="$TMP_DIR/bin/claude" \
  CLAUDE_COMPLETION="$CLAUDE_COMPLETION" \
  FISH_BIN="$FISH" \
  PATH="$TMP_DIR/bin:/opt/homebrew/bin:/usr/bin:/bin" \
  "$CLAUDE_CHECK"

cat >"$TMP_DIR/incomplete-claude.fish" <<'EOF'
complete -c claude -l help -f -d "Display help"
EOF

set +e
drift_output="$(CLAUDE_BIN="$TMP_DIR/bin/claude" \
  CLAUDE_COMPLETION="$TMP_DIR/incomplete-claude.fish" \
  FISH_BIN="$FISH" \
  PATH="$TMP_DIR/bin:/opt/homebrew/bin:/usr/bin:/bin" \
  "$CLAUDE_CHECK" 2>&1)"
drift_status=$?
set -e

[[ "$drift_status" -eq 1 ]] || fail "Incomplete Claude completions did not report drift"
[[ "$drift_output" == *'missing option --future-mode'* ]] || fail "Option drift was not identified"
[[ "$drift_output" == *'missing subcommand launch'* ]] || fail "Subcommand drift was not identified"
