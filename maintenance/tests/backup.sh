#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'backup test: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMP_DIR/bin"
ln -s "$ROOT_DIR/tools/bin/config/.local/bin/thaw-config" "$TMP_DIR/bin/thaw-config"
printf 'preferences fixture\n' >"$TMP_DIR/preferences.plist"
export PATH="$TMP_DIR/bin:/usr/bin:/bin"
export THAW_PREFERENCES_FILE="$TMP_DIR/preferences.plist"

for target in thaw all; do
  export THAW_BACKUP_DIR="$TMP_DIR/$target"
  "$ROOT_DIR/dotfiles" backup "$target" >"$TMP_DIR/$target.out"
  backups=("$THAW_BACKUP_DIR"/*.plist)
  [[ "${#backups[@]}" -eq 1 ]] || fail "$target did not produce one backup"
  cmp "$THAW_PREFERENCES_FILE" "${backups[0]}" || fail "$target changed preferences"
  grep -qF 'Backed up Thaw preferences:' "$TMP_DIR/$target.out" || fail "$target hid owner output"
done

THAW_PREFERENCES_FILE="$TMP_DIR/missing.plist" \
  "$ROOT_DIR/dotfiles" backup all >"$TMP_DIR/skipped.out"
grep -qF 'skipping backup' "$TMP_DIR/skipped.out" || fail "missing preferences did not skip"

printf 'regular file\n' >"$TMP_DIR/blocked"
if THAW_BACKUP_DIR="$TMP_DIR/blocked" "$ROOT_DIR/dotfiles" backup all \
  >"$TMP_DIR/failed.out" 2>"$TMP_DIR/failed.err"; then
  fail "backup failure returned success"
fi

for target in raycast unknown; do
  set +e
  "$ROOT_DIR/dotfiles" backup "$target" >"$TMP_DIR/invalid.out" 2>"$TMP_DIR/invalid.err"
  status=$?
  set -e
  [[ "$status" -eq 2 ]] || fail "$target was accepted"
done

rm "$TMP_DIR/bin/thaw-config"
if "$ROOT_DIR/dotfiles" backup all >"$TMP_DIR/missing.out" 2>"$TMP_DIR/missing.err"; then
  fail "missing owner returned success"
fi
grep -qF 'required owner is not installed: thaw-config' "$TMP_DIR/missing.err" ||
  fail "missing owner did not identify the prerequisite"

printf 'backup test: passed\n'
