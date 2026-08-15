#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'tmux install test: %s\n' "$*" >&2
  exit 1
}

fake_bin="$TMP_DIR/homebrew/bin"
managed_bin="$TMP_DIR/mise/installs/tpack/latest/bin"
call_log="$TMP_DIR/calls.log"
mkdir -p "$fake_bin" "$managed_bin" "$TMP_DIR/home"

cat >"$fake_bin/stow" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'stow %s\n' "$*" >>"$CALL_LOG"
EOF

cat >"$fake_bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == -V ]]; then
  printf 'tmux 3.5a\n'
  exit 0
fi
printf 'tmux PATH=%s ARGS=%s\n' "$PATH" "$*" >>"$CALL_LOG"
if [[ "$*" == *"source-file"* && "$*" != *"source-file -n"* ]]; then
  printf "'tpack init' returned 1\n" >&2
  exit 1
fi
EOF

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$fake_bin/mise" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == which && "\${2:-}" == tpack ]]; then
  printf '%s\n' '$managed_bin/tpack'
  exit 0
fi
exit 1
EOF

cat >"$fake_bin/tpack" <<'EOF'
#!/usr/bin/env bash
printf "'tpack init' returned 1\n" >&2
printf 'legacy-tpack %s\n' "$*" >>"$CALL_LOG"
exit 1
EOF

cat >"$managed_bin/tpack" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'managed-tpack PATH=%s ARGS=%s\n' "$PATH" "$*" >>"$CALL_LOG"
EOF

chmod +x "$fake_bin"/* "$managed_bin/tpack"

CALL_LOG="$call_log" \
  HOME="$TMP_DIR/home" \
  DOTFILES="$ROOT_DIR" \
  HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
  PATH="$fake_bin:/usr/bin:/bin" \
  /bin/bash "$ROOT_DIR/tools/tmux/install.sh"

grep -F 'managed-tpack ' "$call_log" >/dev/null ||
  fail "installer did not use the TPack binary owned by mise"
! grep -F 'legacy-tpack ' "$call_log" >/dev/null ||
  fail "installer used the shadowing legacy Homebrew cask"
grep -F "tmux PATH=$managed_bin:" "$call_log" >/dev/null ||
  fail "isolated tmux validation could not resolve the mise-owned TPack"
grep -F 'source-file -n ' "$call_log" >/dev/null ||
  fail "tmux validation executed the config instead of parsing it"

printf 'tmux install test: passed\n'
