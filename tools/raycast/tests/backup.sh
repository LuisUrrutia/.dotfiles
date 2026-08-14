#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"
RAYCAST_CONFIG="$ROOT_DIR/tools/raycast/config/.local/bin/raycast-config"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

source_file="$TMP_DIR/Raycast fixture.rayconfig"
backup_dir="$TMP_DIR/backups"
export_dir="$TMP_DIR/exports"
outcome_file="$TMP_DIR/outcome"
mkdir -p "$export_dir"
printf 'fixture export\n' >"$source_file"

RAYCAST_BACKUP_DIR="$backup_dir" DOTFILES_BACKUP_OUTCOME_FILE="$outcome_file" \
  "$RAYCAST_CONFIG" backup "$source_file" >/dev/null
[[ "$(<"$outcome_file")" == completed ]]
cmp "$source_file" "$backup_dir/$(basename "$source_file")" >/dev/null

RAYCAST_BACKUP_DIR="$backup_dir" RAYCAST_EXPORT_DIR="$export_dir" \
  RAYCAST_CONFIG_DRY_RUN=1 DOTFILES_BACKUP_OUTCOME_FILE="$outcome_file" \
  "$RAYCAST_CONFIG" backup >/dev/null
[[ "$(<"$outcome_file")" == skipped ]]
