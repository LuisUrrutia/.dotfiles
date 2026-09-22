#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fish evaluates the fixture commands.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FISH_BIN="$(command -v fish)"
PYTHON_BIN="$(command -v python3)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'Fish plugin update test: %s\n' "$*" >&2
  exit 1
}

fixture_root="$TMP_DIR/repository"
fixture_home="$TMP_DIR/home"
fixture_config="$TMP_DIR/config"
fixture_bin="$TMP_DIR/bin"
mkdir -p "$fixture_root/cli" "$fixture_root/maintenance" \
  "$fixture_home" "$fixture_config/fish/functions" "$fixture_bin"
cp "$ROOT_DIR/dotfiles" "$fixture_root/dotfiles"
cp "$ROOT_DIR"/cli/*.sh "$fixture_root/cli/"
cp "$ROOT_DIR/maintenance/update.sh" "$fixture_root/maintenance/update.sh"
ln -s "$FISH_BIN" "$fixture_bin/fish"
ln -s "$PYTHON_BIN" "$fixture_bin/python3"
printf 'fixture/plugin\n' >"$fixture_root/fish_plugins"
ln -s "$fixture_root/fish_plugins" "$fixture_config/fish/fish_plugins"

cat >"$fixture_config/fish/functions/fisher.fish" <<'FISH'
function fisher --description 'Check Fisher state across update processes' --argument-names action
    test "$action" = update; or return 20
    status is-interactive; and return 21
    if not contains -- fixture/plugin $_fisher_plugins
        printf 'Fisher installed plugin state was not loaded\n' >&2
        return 22
    end
    set --universal _fisher_fixture_updates (math $_fisher_fixture_updates + 1)
end
FISH

export HOME="$fixture_home"
export XDG_CONFIG_HOME="$fixture_config"
export XDG_DATA_HOME="$TMP_DIR/data"
export XDG_STATE_HOME="$TMP_DIR/state"
export XDG_CACHE_HOME="$TMP_DIR/cache"
export PATH="$fixture_bin:/usr/bin:/bin"

fish --command 'set --universal _fisher_plugins fixture/plugin; set --universal _fisher_fixture_updates 0'

for expected_updates in 1 2; do
  if ! "$fixture_root/dotfiles" update >"$TMP_DIR/update.log" 2>&1; then
    cat "$TMP_DIR/update.log" >&2
    fail "Update did not load Fisher's persisted plugin state"
  fi

  grep -qF '[update] Fish plugins: completed' "$TMP_DIR/update.log" ||
    fail "Fish plugin update did not complete"
  actual_updates="$(fish --command 'printf "%s\n" $_fisher_fixture_updates')"
  [[ "$actual_updates" == "$expected_updates" ]] || fail "plugin state was not persisted"
  [[ -L "$fixture_config/fish/fish_plugins" && -f "$fixture_config/fish/fish_plugins" ]] ||
    fail "Update lost the managed plugin manifest"
done

printf 'Fish plugin update test: passed\n'
