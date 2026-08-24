#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'vim install test: %s\n' "$*" >&2
  exit 1
}

fake_bin="$TMP_DIR/homebrew/bin"
managed_bin="$TMP_DIR/mise/installs/tree-sitter/latest"
call_log="$TMP_DIR/calls.log"
mkdir -p "$fake_bin" "$managed_bin" "$TMP_DIR/home"

cat >"$fake_bin/stow" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'stow %s\n' "$*" >>"$CALL_LOG"
EOF

cat >"$fake_bin/mise" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == which && "\${2:-}" == tree-sitter ]]; then
  printf '%s\n' '$managed_bin/tree-sitter'
  exit 0
fi
exit 1
EOF

cat >"$managed_bin/tree-sitter" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'tree-sitter %s\n' "$*" >>"$CALL_LOG"
EOF

cat >"$fake_bin/nvim" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'nvim PATH=%s ARGS=%s\n' "$PATH" "$*" >>"$CALL_LOG"
if tree_sitter_path="$(command -v tree-sitter 2>/dev/null)"; then
  printf 'nvim tree-sitter=%s\n' "$tree_sitter_path" >>"$CALL_LOG"
else
  printf '%s\n' \
    '[nvim-treesitter/install/json] error: ENOENT: no such file or directory (cmd): tree-sitter' >&2
fi
if [[ "${NVIM_TREESITTER_FAIL:-false}" == true &&
  "$*" == *"config.treesitter"* ]]; then
  printf '%s\n' '[nvim-treesitter/install/json] error: parser build failed' >&2
  if [[ "$*" == *"vim.cmd.cquit"* ]]; then
    exit 1
  fi
fi
if [[ "${NVIM_BLINK_FAIL:-false}" == true && "$*" == *"config.blink"* ]]; then
  exit 1
fi
if [[ "${NVIM_LSP_FAIL:-false}" == true && "$*" == *"config.lsp"* ]]; then
  exit 1
fi
if [[ "$*" == *"config.lsp"* ]]; then
  mkdir -p "$HOME/.local/share/nvim/mason/bin"
  printf '#!/usr/bin/env bash\n' >"$HOME/.local/share/nvim/mason/bin/lua-language-server"
  chmod +x "$HOME/.local/share/nvim/mason/bin/lua-language-server"
fi
EOF

cat >"$fake_bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'brew %s\n' "$*" >>"$CALL_LOG"
if [[ "${1:-}" == list && "${2:-}" == --formula && "${3:-}" == lua-language-server ]]; then
  exit 0
fi
if [[ "${1:-}" == uninstall && "${2:-}" == --formula && "${3:-}" == lua-language-server ]]; then
  exit 0
fi
exit 1
EOF

chmod +x "$fake_bin"/* "$managed_bin/tree-sitter"

set +e
CALL_LOG="$call_log" \
  HOME="$TMP_DIR/home" \
  DOTFILES="$ROOT_DIR" \
  HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
  PATH="$fake_bin:/usr/bin:/bin" \
  /bin/bash "$ROOT_DIR/tools/vim/install.sh" \
  >"$TMP_DIR/install.out" 2>"$TMP_DIR/install.err"
install_status=$?
set -e

[[ "$install_status" -eq 0 ]] || fail "installer failed with managed tree-sitter available"
! grep -F 'ENOENT: no such file or directory (cmd): tree-sitter' \
  "$TMP_DIR/install.err" >/dev/null ||
  fail "Neovim could not resolve the mise-owned tree-sitter"
grep -F "nvim tree-sitter=$managed_bin/tree-sitter" "$call_log" >/dev/null ||
  fail "Neovim did not receive the mise-owned tree-sitter on PATH"
grep -F "config.blink" "$call_log" >/dev/null ||
  fail "installer did not verify the blink.cmp native library"
grep -F "config.lsp" "$call_log" >/dev/null ||
  fail "installer did not ensure the Mason-owned language servers"
grep -F "brew uninstall --formula lua-language-server" "$call_log" >/dev/null ||
  fail "installer did not retire the legacy Homebrew language server"
lsp_line="$(grep -nF "config.lsp" "$call_log" | head -1 | cut -d: -f1)"
uninstall_line="$(grep -nF "brew uninstall --formula lua-language-server" "$call_log" | head -1 | cut -d: -f1)"
[[ "$lsp_line" -lt "$uninstall_line" ]] ||
  fail "installer retired Homebrew before verifying the Mason replacement"
! grep -F 'brew "lua-language-server"' "$ROOT_DIR/brewfiles/core" >/dev/null ||
  fail "lua-language-server still has a duplicate Homebrew owner"

missing_home="$TMP_DIR/missing-mason/home"
missing_log="$TMP_DIR/missing-mason/calls.log"
mkdir -p "$missing_home" "$(dirname "$missing_log")"
set +e
CALL_LOG="$missing_log" \
  HOME="$missing_home" \
  DOTFILES="$ROOT_DIR" \
  HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
  PATH="$fake_bin:/usr/bin:/bin" \
  /bin/bash "$ROOT_DIR/tools/vim/migrate-legacy.sh" \
  >"$TMP_DIR/missing-mason/stdout" 2>"$TMP_DIR/missing-mason/stderr"
missing_mason_status=$?
set -e
[[ "$missing_mason_status" -ne 0 ]] ||
  fail "missing Mason replacement did not stop the legacy migration"
grep -F "preserving the legacy Homebrew formula" "$TMP_DIR/missing-mason/stderr" >/dev/null ||
  fail "missing Mason replacement did not explain the safe fallback"
[[ ! -s "$missing_log" ]] ||
  fail "legacy Homebrew formula was inspected before Mason ownership was proven"

set +e
CALL_LOG="$call_log" \
  NVIM_BLINK_FAIL=true \
  HOME="$TMP_DIR/home" \
  DOTFILES="$ROOT_DIR" \
  HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
  PATH="$fake_bin:/usr/bin:/bin" \
  /bin/bash "$ROOT_DIR/tools/vim/install.sh" \
  >"$TMP_DIR/blink-failure.out" 2>"$TMP_DIR/blink-failure.err"
blink_failure_status=$?
set -e

[[ "$blink_failure_status" -ne 0 ]] ||
  fail "missing blink.cmp native library did not fail the Tool Installer"

set +e
CALL_LOG="$call_log" \
  NVIM_LSP_FAIL=true \
  HOME="$TMP_DIR/home" \
  DOTFILES="$ROOT_DIR" \
  HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
  PATH="$fake_bin:/usr/bin:/bin" \
  /bin/bash "$ROOT_DIR/tools/vim/install.sh" \
  >"$TMP_DIR/lsp-failure.out" 2>"$TMP_DIR/lsp-failure.err"
lsp_failure_status=$?
set -e

[[ "$lsp_failure_status" -ne 0 ]] ||
  fail "failed Mason language server installation did not fail the Tool Installer"

set +e
CALL_LOG="$call_log" \
  NVIM_TREESITTER_FAIL=true \
  HOME="$TMP_DIR/home" \
  DOTFILES="$ROOT_DIR" \
  HOMEBREW_PREFIX="$TMP_DIR/homebrew" \
  PATH="$fake_bin:/usr/bin:/bin" \
  /bin/bash "$ROOT_DIR/tools/vim/install.sh" \
  >"$TMP_DIR/parser-failure.out" 2>"$TMP_DIR/parser-failure.err"
parser_failure_status=$?
set -e

[[ "$parser_failure_status" -ne 0 ]] ||
  fail "failed Treesitter parser installation did not fail the Tool Installer"

printf 'vim install test: passed\n'
