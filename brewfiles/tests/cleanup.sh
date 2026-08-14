#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLEANUP="$ROOT_DIR/cleanup.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'cleanup test: %s\n' "$*" >&2
  exit 1
}

fixture="$TMP_DIR/repo"
fake_bin="$TMP_DIR/bin"
mkdir -p "$fixture/brewfiles/profiles" "$fake_bin"

printf 'brew "core-tool"\n' >"$fixture/brewfiles/core"
printf 'brew "verification-tool"\n' >"$fixture/brewfiles/verification"
printf 'brew "profile-tool"\n' >"$fixture/brewfiles/profiles/dev"
printf 'brew "selected-tool"\n' >"$fixture/selected"

cat >"$fake_bin/brew" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

brewfile=""
for argument in "$@"; do
  case "$argument" in
  --file=*) brewfile="${argument#--file=}" ;;
  esac
done

[[ "$1" == bundle && "$2" == cleanup && -n "$brewfile" ]]
cp "$brewfile" "$BREW_CLEANUP_CAPTURE"
EOF
chmod +x "$fake_bin/brew"

run_cleanup() {
  local capture="$1"
  shift

  BREW_CLEANUP_CAPTURE="$capture" \
    DOTFILES="$fixture" \
    PATH="$fake_bin:/usr/bin:/bin" \
    /bin/bash "$CLEANUP" "$@" >/dev/null
}

core_capture="$TMP_DIR/core"
run_cleanup "$core_capture" --core-only
grep -F 'brew "core-tool"' "$core_capture" >/dev/null ||
  fail "core-only cleanup omitted core"
grep -F 'brew "verification-tool"' "$core_capture" >/dev/null ||
  fail "core-only cleanup omitted verification"
if grep -F 'brew "profile-tool"' "$core_capture" >/dev/null; then
  fail "core-only cleanup included a profile"
fi

selected_capture="$TMP_DIR/selected"
run_cleanup "$selected_capture" --file "$fixture/selected"
grep -F 'brew "core-tool"' "$selected_capture" >/dev/null ||
  fail "selected cleanup omitted core"
grep -F 'brew "verification-tool"' "$selected_capture" >/dev/null ||
  fail "selected cleanup omitted verification"
grep -F 'brew "selected-tool"' "$selected_capture" >/dev/null ||
  fail "selected cleanup omitted the selected Brewfile"
if grep -F 'brew "profile-tool"' "$selected_capture" >/dev/null; then
  fail "selected cleanup included an unselected profile"
fi
