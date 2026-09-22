#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/tools" "$fixture_dir/bin"

cat > "$fixture_dir/tools/lib.sh" <<'LIB'
source "$DOTFILES_TEST_ROOT/tools/lib.sh"
require_app() { :; }
stow_config() { :; }
require_brew_bin() { bin_path="$DOTFILES/bin/duti"; }
LIB

cat > "$fixture_dir/bin/duti" <<'DUTI'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == -s ]]; then
  [[ "$2" == dev.zed.Zed && "$4" == all ]]
  printf '%s\n' "$3" >> "$ASSOCIATION_STATE/writes"
  [[ "$ASSOCIATION_MODE" != write-failure || "$3" != .yaml ]]
  exit $?
fi
[[ "$1" == -x ]]
count_file="$ASSOCIATION_STATE/$2"
count=0
[[ ! -f "$count_file" ]] || read -r count < "$count_file"
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"
if [[ "$count" -eq 1 || ( "$ASSOCIATION_MODE" == mismatch && "$2" == yaml ) ]]; then
  printf '%s\n' 'Previous.app' '/Applications/Previous.app' 'test.previous'
else
  printf '%s\n' 'Zed.app' '/Applications/Zed.app' 'dev.zed.Zed'
fi
DUTI

printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture_dir/bin/sleep"
chmod +x "$fixture_dir/bin/duti" "$fixture_dir/bin/sleep"

for mode in eventual mismatch write-failure; do
  state="$fixture_dir/$mode"
  mkdir -p "$state"
  status=0
  DOTFILES="$fixture_dir" DOTFILES_TEST_ROOT="$ROOT_DIR" ASSOCIATION_STATE="$state" ASSOCIATION_MODE="$mode" \
    PATH="$fixture_dir/bin:$PATH" /bin/bash "$ROOT_DIR/tools/zed/install.sh" \
    > "$state/output" 2>&1 || status=$?

  expected_status=1
  [[ "$mode" != eventual ]] || expected_status=0
  [[ "$status" -eq "$expected_status" ]]
  [[ "$(cat "$state/writes")" == $'.json\n.yaml\n.toml\n.sh' ]]
  [[ "$(cat "$state/sh")" -eq 2 ]]
  if [[ "$mode" == eventual ]]; then
    [[ ! -s "$state/output" ]]
  elif [[ "$mode" == mismatch ]]; then
    [[ "$(cat "$state/yaml")" -eq 10 ]]
    grep -q 'verification failed for .yaml' "$state/output"
  else
    [[ ! -f "$state/yaml" ]]
    grep -q 'could not set Zed as the default for .yaml' "$state/output"
  fi
done

printf '%s\n' 'Zed associations test: passed'
