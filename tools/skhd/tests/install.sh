#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'skhd install test: %s\n' "$*" >&2
  exit 1
}

fake_bin="$TMP_DIR/homebrew/bin"
call_log="$TMP_DIR/calls.log"
mkdir -p "$fake_bin" "$TMP_DIR/home"

cat >"$fake_bin/stow" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'stow %s\n' "$*" >>"$CALL_LOG"
EOF

cat >"$fake_bin/skhd" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'skhd %s\n' "$*" >>"$CALL_LOG"
case "${1:-}" in
--install-service)
  printf "skhd: service file '$HOME/Library/LaunchAgents/com.koekeishiya.skhd.plist' is already installed! abort..\n" >&2
  exit 1
  ;;
--start-service | --status) exit 0 ;;
*) exit 2 ;;
esac
EOF

chmod +x "$fake_bin/stow" "$fake_bin/skhd"

CALL_LOG="$call_log" \
  HOME="$TMP_DIR/home" \
  DOTFILES="$ROOT_DIR" \
  HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
  PATH="$fake_bin:/usr/bin:/bin" \
  /bin/bash "$ROOT_DIR/tools/skhd/install.sh"

! grep -F 'skhd --install-service' "$call_log" >/dev/null ||
  fail "installer retried the non-idempotent service-file creation path"
grep -F 'skhd --start-service' "$call_log" >/dev/null ||
  fail "installer did not ensure the existing service was running"

printf 'skhd install test: passed\n'
