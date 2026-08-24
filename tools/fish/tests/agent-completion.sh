#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fish expands the environment variables in this snippet.

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FISH="${FISH_BIN:-$(command -v fish)}"
CODEX_COMPLETION="$DOTFILES_ROOT/tools/fish/config/.config/fish/completions/codex.fish"
CLAUDE_COMPLETION="$DOTFILES_ROOT/tools/fish/config/.config/fish/conf.d/05_claude-completions.fish"
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

claude_options="$(complete_for "$CLAUDE_COMPLETION" 'claude --eff')"
[[ "$claude_options" == *'--effort'* ]] || fail "Current Claude options are absent"

claude_commands="$(complete_for "$CLAUDE_COMPLETION" 'claude ag')"
[[ "$claude_commands" == *$'agents\t'* ]] || fail "Current Claude subcommands are absent"
