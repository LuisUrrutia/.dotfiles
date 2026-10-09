#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/brew/bin"
cat >"$TMP_DIR/brew/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
'extension list') cat "$EXTENSIONS" ;;
'extension remove gh-image')
  printf '%s\n' "$*" >>"$CALL_LOG"
  sed '/drogers0\/gh-image/d' "$EXTENSIONS" >"$EXTENSIONS.next"
  mv "$EXTENSIONS.next" "$EXTENSIONS"
  ;;
'extension install github/gh-stack')
  printf '%s\n' "$*" >>"$CALL_LOG"
  printf 'gh stack github/gh-stack v0.2.0\n' >>"$EXTENSIONS"
  ;;
*) exit 2 ;;
esac
EOF
chmod +x "$TMP_DIR/brew/bin/gh"
export EXTENSIONS="$TMP_DIR/extensions"
export CALL_LOG="$TMP_DIR/calls"
export HOMEBREW_PREFIX="$TMP_DIR/brew"
export DOTFILES="$ROOT_DIR"
printf 'gh image drogers0/gh-image v1.0.0\n' >"$EXTENSIONS"

/bin/bash "$ROOT_DIR/tools/gh/install.sh"
/bin/bash "$ROOT_DIR/tools/gh/install.sh"

printf 'extension remove gh-image\nextension install github/gh-stack\n' >"$TMP_DIR/expected"
cmp "$TMP_DIR/expected" "$CALL_LOG"
[[ "$(cat "$EXTENSIONS")" == 'gh stack github/gh-stack v0.2.0' ]]
printf 'GitHub CLI install test: passed\n'
