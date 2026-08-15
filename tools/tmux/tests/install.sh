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
legacy_plugin="$TMP_DIR/home/.tmux/plugins/tmux-resurrect"
mkdir -p "$fake_bin" "$managed_bin" "$legacy_plugin/.git"

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
set -euo pipefail
printf 'git %s\n' "$*" >>"$CALL_LOG"
if [[ "$*" == *"config --get remote.origin.url"* ]]; then
  printf 'https://legacy-user@github.com/tmux-plugins/tmux-resurrect\n'
fi
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
if [[ "${1:-}" == install ]]; then
  attempt=0
  if [[ -f "$TPACK_ATTEMPT_FILE" ]]; then
    attempt="$(<"$TPACK_ATTEMPT_FILE")"
  fi
  attempt=$((attempt + 1))
  printf '%s\n' "$attempt" >"$TPACK_ATTEMPT_FILE"
  if [[ "$attempt" -le "${TPACK_FAILURES_BEFORE_SUCCESS:-2}" ]]; then
    printf 'Installing "tmux-plugins/tmux-resurrect"\n'
    printf 'tpack: error: "tmux-plugins/tmux-resurrect" download fail\n' >&2
    exit 1
  fi
fi
EOF

chmod +x "$fake_bin"/* "$managed_bin/tpack"

run_install() {
  local attempt_file="$1"
  shift
  /usr/bin/env \
    CALL_LOG="$call_log" \
    TPACK_ATTEMPT_FILE="$attempt_file" \
    DOTFILES_TPACK_RETRY_DELAY_SECONDS=0 \
    HOME="$TMP_DIR/home" \
    DOTFILES="$ROOT_DIR" \
    HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
    PATH="$fake_bin:/usr/bin:/bin" \
    "$@" \
    /bin/bash "$ROOT_DIR/tools/tmux/install.sh"
}

run_install "$TMP_DIR/tpack-attempt"

grep -F 'managed-tpack ' "$call_log" >/dev/null ||
  fail "installer did not use the TPack binary owned by mise"
! grep -F 'legacy-tpack ' "$call_log" >/dev/null ||
  fail "installer used the shadowing legacy Homebrew cask"
grep -F "tmux PATH=$managed_bin:" "$call_log" >/dev/null ||
  fail "isolated tmux validation could not resolve the mise-owned TPack"
grep -F 'source-file -n ' "$call_log" >/dev/null ||
  fail "tmux validation executed the config instead of parsing it"
grep -F -- "-c transfer.credentialsInUrl=allow -C $legacy_plugin remote set-url origin https://github.com/tmux-plugins/tmux-resurrect" \
  "$call_log" >/dev/null ||
  fail "legacy TPack origin retained embedded GitHub credentials"
[[ "$(<"$TMP_DIR/tpack-attempt")" -eq 3 ]] ||
  fail "transient TPack download failure was not retried"

set +e
run_install "$TMP_DIR/tpack-persistent-attempt" \
  TPACK_FAILURES_BEFORE_SUCCESS=99 \
  DOTFILES_TPACK_MAX_ATTEMPTS=3 \
  >"$TMP_DIR/persistent.out" 2>"$TMP_DIR/persistent.err"
persistent_status=$?
set -e
[[ "$persistent_status" -eq 1 ]] ||
  fail "persistent TPack download failure did not fail the installer"
[[ "$(<"$TMP_DIR/tpack-persistent-attempt")" -eq 3 ]] ||
  fail "persistent TPack failure did not exhaust the retry limit"
grep -F 'TPack could not install all plugins after 3 attempts' "$TMP_DIR/persistent.err" >/dev/null ||
  fail "persistent TPack failure did not explain how to recover"

printf 'tmux install test: passed\n'
