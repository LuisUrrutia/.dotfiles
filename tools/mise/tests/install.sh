#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MISE_INSTALL="$ROOT_DIR/tools/mise/install.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'mise install test: %s\n' "$*" >&2
  exit 1
}

make_fakes() {
  local fake_bin="$1"

  mkdir -p "$fake_bin"

  cat >"$fake_bin/stow" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'stow %s\n' "$*" >>"$CALL_LOG"
EOF

  cat >"$fake_bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'mise %s\n' "$*" >>"$CALL_LOG"
if [[ "${1:-}" == install && "${2:-}" == --yes ]]; then
  exit 0
fi
if [[ "${1:-}" == which ]]; then
  [[ "${MISE_MISSING_COMMAND:-}" != "${2:-}" ]] || exit 1
  printf '/managed/by/mise/%s\n' "$2"
  exit 0
fi
exit 1
EOF

  cat >"$fake_bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'brew %s\n' "$*" >>"$CALL_LOG"
if [[ "${1:-}" == list && "${2:-}" == --cask ]]; then
  case "${3:-}" in
  claude-code | claude-code@latest | codex | tpack) exit 0 ;;
  *) exit 1 ;;
  esac
fi
if [[ "${1:-}" == list && "${2:-}" == --formula && "${3:-}" == tpack ]]; then
  exit 0
fi
if [[ "${1:-}" == uninstall && "${2:-}" == --cask ]]; then
  exit 0
fi
if [[ "${1:-}" == uninstall && "${2:-}" == --formula ]]; then
  exit 0
fi
exit 1
EOF

  chmod +x "$fake_bin/stow" "$fake_bin/mise" "$fake_bin/brew"
}

run_install() {
  local case_name="$1"
  local fake_bin="$TMP_DIR/$case_name/homebrew/bin"
  local case_home="$TMP_DIR/$case_name/home"

  CALL_LOG="$TMP_DIR/$case_name/calls.log"
  export CALL_LOG
  make_fakes "$fake_bin"
  mkdir -p "$case_home"

  HOME="$case_home" \
    DOTFILES="$ROOT_DIR" \
    HOMEBREW_PREFIX="$TMP_DIR/$case_name/homebrew" \
    PATH="$fake_bin:/usr/bin:/bin" \
    /bin/bash "$MISE_INSTALL" >"$TMP_DIR/$case_name/stdout" \
    2>"$TMP_DIR/$case_name/stderr"
}

run_install success

expected_sequence="$TMP_DIR/expected-sequence"
cat >"$expected_sequence" <<EOF
stow -v --restow --no-folding -d $ROOT_DIR/tools/mise -t $TMP_DIR/success/home config
mise install --yes
mise which claude
mise which codex
mise which tpack
brew list --cask claude-code
brew uninstall --cask claude-code
brew list --cask claude-code@latest
brew uninstall --cask claude-code@latest
brew list --cask codex
brew uninstall --cask codex
brew list --cask tpack
brew uninstall --cask tpack
brew list --formula tpack
brew uninstall --formula tpack
EOF
cmp -s "$expected_sequence" "$TMP_DIR/success/calls.log" ||
  fail "mise install and legacy migration ran in the wrong order"
! grep -E 'brew (list|uninstall) --cask (claude|codexbar)$' \
  "$TMP_DIR/success/calls.log" >/dev/null ||
  fail "desktop app casks were included in the CLI migration"

set +e
MISE_MISSING_COMMAND=tpack run_install missing-tpack
missing_status=$?
set -e
[[ "$missing_status" -eq 1 ]] || fail "missing mise command did not fail the migration"
grep -F 'preserving legacy Homebrew packages' "$TMP_DIR/missing-tpack/stderr" >/dev/null ||
  fail "missing mise command did not explain the safe fallback"
! grep -F 'brew ' "$TMP_DIR/missing-tpack/calls.log" >/dev/null ||
  fail "legacy packages were inspected before mise ownership was proven"

grep -F '"github:tmuxpack/tpack" = "latest"' \
  "$ROOT_DIR/tools/mise/config/.config/mise/config.toml" >/dev/null ||
  fail "TPack is not declared in the mise-owned portable toolchain"
! grep -F 'credential_command' \
  "$ROOT_DIR/tools/mise/config/.config/mise/config.toml" >/dev/null ||
  fail "fresh mise install still requires an explicit GitHub credential command"
! grep -F 'tmuxpack/tpack/tpack' "$ROOT_DIR/brewfiles/core" >/dev/null ||
  fail "TPack still has a duplicate Homebrew owner"

bootstrap_plan="$(/bin/bash "$ROOT_DIR/install.sh" --dry-run --core-only)"
mise_line="$(printf '%s\n' "$bootstrap_plan" | grep -n -m 1 '^  - mise$' | cut -d: -f1)"
claude_line="$(printf '%s\n' "$bootstrap_plan" | grep -n -m 1 '^  - claude$' | cut -d: -f1)"
[[ -n "$mise_line" && -n "$claude_line" && "$mise_line" -lt "$claude_line" ]] ||
  fail "Bootstrapper does not establish mise before dependent Tool Installers"

printf 'mise install test: passed\n'
