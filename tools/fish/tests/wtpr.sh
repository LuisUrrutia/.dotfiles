#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fish expands the fixture variables.

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FISH="${FISH_BIN:-$(command -v fish)}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/home"
cat >"$TMP_DIR/bin/gh" <<'EOF'
#!/bin/sh
printf '%s\n' '[{"number":42,"title":"Example PR"}]'
EOF
cat >"$TMP_DIR/bin/wt" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$WT_LOG"
EOF
chmod +x "$TMP_DIR/bin/gh" "$TMP_DIR/bin/wt"

HOME="$TMP_DIR/home" PATH="$TMP_DIR/bin:/opt/homebrew/bin:/usr/bin:/bin" \
  FISH_CONFIG="$DOTFILES_ROOT/tools/fish/config/.config/fish" WT_LOG="$TMP_DIR/wt.log" \
  "$FISH" --no-config -c '
    source "$FISH_CONFIG/functions/wtpr.fish"
    source "$FISH_CONFIG/completions/wtpr.fish"
    set -l candidate (complete -C "wtpr " | string split -f1 \t)
    test (count $candidate) -eq 1; or exit 1
    wtpr "$candidate"
  ' </dev/null

[[ "$(cat "$TMP_DIR/wt.log")" == $'switch\npr:42' ]] || {
  printf 'wtpr did not accept its completed PR number\n' >&2
  exit 1
}
