#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/tools/hammerspoon" "$fixture_dir/brew/bin"
ln -s "$ROOT_DIR/tools/hammerspoon/config" "$fixture_dir/tools/hammerspoon/config"

cat > "$fixture_dir/tools/lib.sh" <<'LIB'
source "$DOTFILES_TEST_ROOT/tools/lib.sh"
require_app() { [[ "$HAMMERSPOON_TEST_APP" == present ]] || exit 0; }
LIB

for mode in missing-app missing-blueutil installed; do
  target="$fixture_dir/$mode"
  mkdir -p "$target"
  app=present
  [[ "$mode" != missing-app ]] || app=missing
  if [[ "$mode" == installed ]]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture_dir/brew/bin/blueutil"
    chmod +x "$fixture_dir/brew/bin/blueutil"
  fi

  env HOME="$target" DOTFILES="$fixture_dir" DOTFILES_TEST_ROOT="$ROOT_DIR" \
    HOMEBREW_PREFIX="$fixture_dir/brew" HAMMERSPOON_TEST_APP="$app" \
    /bin/bash "$ROOT_DIR/tools/hammerspoon/install.sh" > "$target/output" 2>&1

  if [[ "$mode" == missing-app ]]; then
    [[ ! -e "$target/.hammerspoon" ]]
  else
    for source in init.lua bindings.lua modules/caffeinate_at_home.lua modules/bluetooth_sleep_manager.lua; do
      if [[ ! -L "$target/.hammerspoon/$source" ]]; then
        printf 'Missing Hammerspoon config in %s: %s\n' "$mode" "$source" >&2
        exit 1
      fi
      cmp "$target/.hammerspoon/$source" "$ROOT_DIR/tools/hammerspoon/config/.hammerspoon/$source"
    done
    [[ ! -L "$target/.hammerspoon" ]]
  fi
  printf 'ok - Hammerspoon installer: %s\n' "$mode"
done
