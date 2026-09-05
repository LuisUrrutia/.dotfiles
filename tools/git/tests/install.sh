#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
REAL_STOW="$(command -v stow)"
export REAL_STOW
mkdir -p "$TMP_ROOT/dotfiles/tools" "$TMP_ROOT/brew/bin"
ln -s "$ROOT_DIR/tools/git" "$TMP_ROOT/dotfiles/tools/git"
ln -s "$ROOT_DIR/tools/lib.sh" "$TMP_ROOT/dotfiles/tools/lib.sh"
ln -s "$(command -v git)" "$TMP_ROOT/brew/bin/git"

setup_home() {
  HOME_DIR="$TMP_ROOT/$1"
  mkdir -p "$HOME_DIR/.config/git"
  printf '[user]\n  name = Example\n  email = example@example.com\n' >"$HOME_DIR/.gitconfig"
  printf '[core]\n  editor = custom-editor\n' >"$HOME_DIR/.config/git/local.gitconfig"
  printf 'private.local\n' >"$HOME_DIR/.config/git/ignore"
  cp "$HOME_DIR/.gitconfig" "$HOME_DIR/original"
}

run_install() {
  HOME="$HOME_DIR" DOTFILES="$TMP_ROOT/dotfiles" HOMEBREW_PREFIX="$TMP_ROOT/brew" \
    /bin/bash "$ROOT_DIR/tools/git/install.sh" >"$HOME_DIR/install.out" 2>"$HOME_DIR/install.err"
}

assert_original_files() {
  cmp "$HOME_DIR/original" "$HOME_DIR/.gitconfig"
  [[ "$(cat "$HOME_DIR/.config/git/ignore")" == private.local ]]
  [[ "$(git config --file "$HOME_DIR/.config/git/local.gitconfig" core.editor)" == custom-editor ]]
  [[ ! -L "$HOME_DIR/.config/git/local.gitconfig" ]]
  [[ ! -L "$HOME_DIR/.config/git/ignore" ]]
}

test_conflict_preserves_live_files() {
  setup_home conflict
  printf '*.custom binary\n' >"$HOME_DIR/.config/git/attributes"

  if run_install; then
    echo 'Expected Stow conflict to fail' >&2
    return 1
  fi

  assert_original_files
  [[ "$(cat "$HOME_DIR/.config/git/attributes")" == '*.custom binary' ]]
  [[ ! -e "$HOME_DIR/.config/git/allowed_signers" ]]
}

inject_stow_failure() {
  mkdir -p "$HOME_DIR/bin"
  cat >"$HOME_DIR/bin/stow" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
for argument in "$@"; do
  if [[ "$argument" == --simulate ]]; then
    exec "$REAL_STOW" "$@"
  fi
done
"$REAL_STOW" "$@"
exit 42
SCRIPT
  chmod +x "$HOME_DIR/bin/stow"
}

test_stow_failure_restores_migration() {
  setup_home rollback
  ln -s "$ROOT_DIR/tools/git/config/.config/git/attributes" "$HOME_DIR/.config/git/attributes"
  inject_stow_failure

  if PATH="$HOME_DIR/bin:$PATH" run_install; then
    echo 'Expected injected Stow failure' >&2
    return 1
  fi

  assert_original_files
  [[ -L "$HOME_DIR/.config/git/attributes" ]]
  [[ ! -e "$HOME_DIR/.config/git/allowed_signers" ]]
  [[ ! -e "$HOME_DIR/.local/bin/git-recent-branches" ]]
}

test_successful_install() {
  setup_home success

  run_install

  [[ -L "$HOME_DIR/.config/git/local.gitconfig" ]]
  [[ -L "$HOME_DIR/.config/git/ignore" ]]
  [[ "$(git config --file "$HOME_DIR/.gitconfig" user.email)" == example@example.com ]]
  run_install
  [[ -L "$HOME_DIR/.config/git/local.gitconfig" ]]
}

test_split_config_drift_is_preserved() {
  setup_home drift
  printf '[include]\n\tpath = ~/.config/git/local.gitconfig\n' >"$HOME_DIR/.gitconfig"
  cp "$HOME_DIR/.gitconfig" "$HOME_DIR/original"

  if run_install; then
    echo 'Expected regular managed config drift to block installation' >&2
    return 1
  fi

  assert_original_files
}

test_fresh_install() {
  HOME_DIR="$TMP_ROOT/fresh"
  mkdir -p "$HOME_DIR"

  run_install

  [[ -L "$HOME_DIR/.config/git/local.gitconfig" ]]
  [[ -x "$HOME_DIR/.local/bin/git-recent-branches" ]]
  [[ -x "$HOME_DIR/.local/bin/git-dm" ]]
  [[ ! -L "$HOME_DIR/.gitconfig" ]]
  git config --file "$HOME_DIR/.gitconfig" --list >/dev/null
}

test_install_updates_repeated_identity_keys() {
  setup_home repeated-identity
  git config --file "$HOME_DIR/.gitconfig" --add user.email previous@example.com

  DOTFILES_GIT_USER_EMAIL=profile@example.com run_install

  [[ "$(git config --file "$HOME_DIR/.gitconfig" --get-all user.email)" == profile@example.com ]]
}

test_folded_directory_rollback() {
  setup_home folded
  rm -r "$HOME_DIR/.config/git"
  ln -s "$ROOT_DIR/tools/git/config/.config/git" "$HOME_DIR/.config/git"
  inject_stow_failure

  if PATH="$HOME_DIR/bin:$PATH" run_install; then
    echo 'Expected injected Stow failure for folded directory' >&2
    return 1
  fi

  cmp "$HOME_DIR/original" "$HOME_DIR/.gitconfig"
  [[ -L "$HOME_DIR/.config/git" ]]
  [[ "$(readlink "$HOME_DIR/.config/git")" == "$ROOT_DIR/tools/git/config/.config/git" ]]
}

tests=(
  test_conflict_preserves_live_files test_stow_failure_restores_migration test_successful_install
  test_split_config_drift_is_preserved test_fresh_install test_folded_directory_rollback
  test_install_updates_repeated_identity_keys
)
if (($# > 0)); then
  tests=("$@")
fi
for test_name in "${tests[@]}"; do
  "$test_name"
  printf 'ok %s\n' "$test_name"
done
