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
cp "$ROOT_DIR/tools/tmux/config/.tmux.conf" "$TMP_DIR/home/.tmux.conf"

plugin_urls="$TMP_DIR/plugin-urls"
/usr/bin/sed -n "s/.*@plugin[[:space:]]*'\\([^']*\\)'.*/\\1/p" \
  "$TMP_DIR/home/.tmux.conf" >"$plugin_urls"
[[ -s "$plugin_urls" ]] || fail "tmux config did not declare any TPack plugins"
while IFS= read -r plugin_url; do
  printf '%s\n' "$plugin_url" |
    /usr/bin/grep -Eq '^https://[^/@[:space:]]+/[^@[:space:]]+$' ||
    fail "TPack plugin must use a credential-free full HTTPS URL: $plugin_url"
done <"$plugin_urls"

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
if [[ "$*" == "--version" ]]; then
  printf 'git version 2.55.0-test\n'
elif [[ "$*" == *"config --get remote.origin.url"* ]]; then
  printf 'https://legacy-user@github.com/tmux-plugins/tmux-resurrect\n'
elif [[ "$*" == *"clone"* ]]; then
  printf "fatal: destination path 'tmux-resurrect' already exists and is not an empty directory.\n" >&2
  printf 'fatal: unable to access https://secret-token@github.com/example/plugin\n' >&2
  exit 128
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
if [[ "${1:-}" == version ]]; then
  printf 'tpack 2.0.4-test\n'
elif [[ "${1:-}" == install ]]; then
  attempt=0
  if [[ -f "$TPACK_ATTEMPT_FILE" ]]; then
    attempt="$(<"$TPACK_ATTEMPT_FILE")"
  fi
  attempt=$((attempt + 1))
  printf '%s\n' "$attempt" >"$TPACK_ATTEMPT_FILE"
  if [[ "$attempt" -le "${TPACK_FAILURES_BEFORE_SUCCESS:-2}" ]]; then
    git clone https://github.com/tmux-plugins/tmux-resurrect.git \
      "$HOME/.tmux/plugins/tmux-resurrect" >/dev/null 2>&1 || true
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
tpack_log_path="$(
  sed -n 's/^Detailed TPack log: //p' "$TMP_DIR/persistent.err" |
    tail -n 1
)"
[[ -n "$tpack_log_path" && -f "$tpack_log_path" ]] ||
  fail "persistent TPack failure did not preserve a detailed log"
[[ "$(stat -f '%Lp' "$tpack_log_path")" == 600 ]] ||
  fail "TPack log was not private"
grep -F 'tpack_version=tpack 2.0.4-test' "$tpack_log_path" >/dev/null ||
  fail "TPack log did not record the managed version"
grep -F 'git_version=git version 2.55.0-test' "$tpack_log_path" >/dev/null ||
  fail "TPack log did not record the Git version"
[[ "$(grep -c 'download fail' "$tpack_log_path")" -eq 3 ]] ||
  fail "TPack log did not retain every failed attempt"
grep -F 'attempt=3/3 status=failed' "$tpack_log_path" >/dev/null ||
  fail "TPack log did not identify the final failed attempt"
grep -F 'git_command=clone' "$tpack_log_path" >/dev/null ||
  fail "TPack log did not identify the failing Git operation"
grep -F 'git_arguments=clone ' "$tpack_log_path" >/dev/null ||
  fail "TPack log did not retain the failing Git arguments"
[[ "$(grep -c '^git_exit=128$' "$tpack_log_path")" -eq 3 ]] ||
  fail "TPack log did not retain each real Git exit status"
grep -F "destination path 'tmux-resurrect' already exists" "$tpack_log_path" >/dev/null ||
  fail "TPack log did not retain the swallowed Git error"
grep -F 'https://<REDACTED>@github.com/' "$tpack_log_path" >/dev/null ||
  fail "TPack Git log did not redact GitHub credentials"
! grep -F 'secret-token' "$tpack_log_path" >/dev/null ||
  fail "TPack Git log leaked GitHub credentials"

printf 'tmux install test: passed\n'
