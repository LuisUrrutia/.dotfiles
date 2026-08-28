#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by Fish.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FISH=/opt/homebrew/bin/fish
PORTS="$ROOT_DIR/tools/fish/config/.config/fish/functions/ports.fish"
IMG2JPG="$ROOT_DIR/tools/fish/config/.config/fish/functions/img2jpg.fish"
IMGOPTIMIZE="$ROOT_DIR/tools/fish/config/.config/fish/functions/imgoptimize.fish"
CLI_ABBRS="$ROOT_DIR/tools/fish/config/.config/fish/conf.d/04_cli-abbrs.fish"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$TMP_DIR/bin"
for fake_command in magick eza ggrep; do
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$TMP_DIR/bin/$fake_command"
  chmod +x "$TMP_DIR/bin/$fake_command"
done

fail() {
  printf 'Fish validation test: %s\n' "$*" >&2
  exit 1
}

if PORTS="$PORTS" "$FISH" --no-config -c \
  'source "$PORTS"; ports 0' >"$TMP_DIR/ports.out" 2>"$TMP_DIR/ports.err"; then
  fail "ports accepted zero"
fi
grep -F 'between 1 and 65535' "$TMP_DIR/ports.err" >/dev/null ||
  fail "ports did not explain its valid range"

if IMGOPTIMIZE="$IMGOPTIMIZE" "$FISH" --no-config -c \
  'source "$IMGOPTIMIZE"; imgoptimize 0' \
  >"$TMP_DIR/imgoptimize.out" 2>"$TMP_DIR/imgoptimize.err"; then
  fail "imgoptimize accepted a zero dimension"
fi
grep -F 'positive integer' "$TMP_DIR/imgoptimize.err" >/dev/null ||
  fail "imgoptimize did not explain its dimension constraint"

touch "$TMP_DIR/input.png"
if PATH="$TMP_DIR/bin:$PATH" IMG2JPG="$IMG2JPG" INPUT_IMAGE="$TMP_DIR/input.png" \
  "$FISH" --no-config -c \
  'source "$IMG2JPG"; img2jpg --max-width 0 "$INPUT_IMAGE"' \
  >"$TMP_DIR/img2jpg.out" 2>"$TMP_DIR/img2jpg.err"; then
  fail "img2jpg accepted a zero dimension"
fi
grep -F 'positive integer' "$TMP_DIR/img2jpg.err" >/dev/null ||
  fail "img2jpg did not explain its dimension constraint"

PATH="$TMP_DIR/bin:$PATH" CLI_ABBRS="$CLI_ABBRS" "$FISH" --no-config --interactive -c \
  'source "$CLI_ABBRS"
    abbr -q ls
    and abbr -q grep
    and not abbr -q ll
    and functions -q ll' </dev/null ||
  fail "interactive CLI shortcuts were not registered"
