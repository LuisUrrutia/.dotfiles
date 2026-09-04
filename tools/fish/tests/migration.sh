[[ ! -L "$upgrade_home/.config/fish/conf.d/zz_atuin.fish" ]] || fail "known broken conf.d link survived"
#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'Fish legacy-link migration test: %s\n' "$*" >&2
  exit 1
}

restow_all() {
  local home_dir="$1"
  local tool_dir=""

  for tool_dir in "$DOTFILES_ROOT"/tools/*; do
    [[ -d "$tool_dir/config" ]] || continue
    stow --no-folding --restow -d "$tool_dir" -t "$home_dir" config
  done
}

# A clean install has no legacy state and still restows every package.
clean_home="$TMP_DIR/clean-home"
mkdir -p "$clean_home"
HOME="$clean_home" DOTFILES="$DOTFILES_ROOT" /bin/bash -c \
  'source "$DOTFILES/tools/fish/migrate-legacy.sh"; migrate_retired_fish_links'
restow_all "$clean_home"
[[ -L "$clean_home/.config/fish/completions/dotfiles.fish" ]] ||
  fail "clean install did not stow canonical completion"

# An upgrade removes only broken links whose literal target names a retired
# source. The target may be in an older clone, so it need not mention this root.
upgrade_home="$TMP_DIR/upgrade-home"
mkdir -p "$upgrade_home/.config/fish/functions" "$upgrade_home/.config/fish/completions" \
  "$upgrade_home/.config/fish/conf.d"
ln -s "$TMP_DIR/old-clone/tools/fish/config/.config/fish/functions/upd.fish" \
  "$upgrade_home/.config/fish/functions/upd.fish"
ln -s ../../../../old-clone/tools/fish/config/.config/fish/functions/backup-configs.fish \
  "$upgrade_home/.config/fish/functions/backup-configs.fish"
ln -s "$TMP_DIR/old-clone/tools/fish/config/.config/fish/completions/upd.fish" \
  "$upgrade_home/.config/fish/completions/upd.fish"
ln -s "$TMP_DIR/old-clone/tools/fish/config/.config/fish/conf.d/zz_atuin.fish" \
  "$upgrade_home/.config/fish/conf.d/zz_atuin.fish"

HOME="$upgrade_home" DOTFILES="$DOTFILES_ROOT" /bin/bash -c \
  'source "$DOTFILES/tools/fish/migrate-legacy.sh"; migrate_retired_fish_links'
[[ ! -L "$upgrade_home/.config/fish/functions/upd.fish" ]] || fail "known broken function link survived"
[[ ! -L "$upgrade_home/.config/fish/functions/backup-configs.fish" ]] || fail "known broken Backup link survived"
[[ ! -L "$upgrade_home/.config/fish/completions/upd.fish" ]] || fail "known broken completion link survived"
restow_all "$upgrade_home"
[[ -L "$upgrade_home/.config/fish/completions/dotfiles.fish" ]] ||
  fail "upgrade install did not stow canonical completion"

# Regular files and foreign symlinks at retired destinations remain untouched.
preserve_home="$TMP_DIR/preserve-home"
foreign_target="$TMP_DIR/foreign/upd.fish"
mkdir -p "$preserve_home/.config/fish/functions" "$preserve_home/.config/fish/completions" \
  "$(dirname "$foreign_target")"
printf 'operator file\n' >"$preserve_home/.config/fish/functions/upd.fish"
ln -s "$foreign_target" "$preserve_home/.config/fish/functions/backup-configs.fish"
ln -s "$foreign_target" "$preserve_home/.config/fish/completions/upd.fish"

HOME="$preserve_home" DOTFILES="$DOTFILES_ROOT" /bin/bash -c \
  'source "$DOTFILES/tools/fish/migrate-legacy.sh"; migrate_retired_fish_links'
[[ -f "$preserve_home/.config/fish/functions/upd.fish" && ! -L "$preserve_home/.config/fish/functions/upd.fish" ]] ||
  fail "regular file was removed"
[[ "$(readlink "$preserve_home/.config/fish/functions/backup-configs.fish")" == "$foreign_target" ]] ||
  fail "foreign function symlink was changed"
[[ "$(readlink "$preserve_home/.config/fish/completions/upd.fish")" == "$foreign_target" ]] ||
  fail "foreign completion symlink was changed"
