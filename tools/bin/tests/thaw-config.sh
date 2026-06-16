#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

export DOTFILES="$ROOT_DIR"
export THAW_PREFERENCES_FILE="$TMP_DIR/com.stonerl.Thaw.plist"
export THAW_BACKUP_DIR="$TMP_DIR/backups"
THAW_CONFIG="$ROOT_DIR/tools/bin/config/.local/bin/thaw-config"

backup_count() {
  if [[ ! -d "$THAW_BACKUP_DIR" ]]; then
    printf '0\n'
    return
  fi

  find "$THAW_BACKUP_DIR" -type f -name 'Thaw*.plist' 2>/dev/null | wc -l | tr -d ' '
}

"$THAW_CONFIG" backup >/dev/null
[[ "$(backup_count)" == "0" ]]

printf '%s\n' 'thaw preferences' >"$THAW_PREFERENCES_FILE"

"$THAW_CONFIG" backup >/dev/null
[[ "$(backup_count)" == "1" ]]
cmp "$THAW_PREFERENCES_FILE" "$(find "$THAW_BACKUP_DIR" -type f -name 'Thaw*.plist')" >/dev/null

"$THAW_CONFIG" backup >/dev/null
[[ "$(backup_count)" == "2" ]]
