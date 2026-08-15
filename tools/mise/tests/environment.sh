#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'mise environment test: %s\n' "$*" >&2
  exit 1
}

fake_bin="$TMP_DIR/homebrew/bin"
managed_bin="$TMP_DIR/mise/installs/fresh-tool/latest/bin"
mkdir -p "$fake_bin" "$managed_bin"

cat >"$fake_bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "$*" == 'env -s bash' ]] || exit 1
printf 'export PATH=%q\n' "$MISE_TEST_MANAGED_BIN:$PATH"
printf 'export JAVA_HOME=%q\n' "$MISE_TEST_JAVA_HOME"
EOF

cat >"$managed_bin/fresh-tool" <<'EOF'
#!/usr/bin/env bash
printf 'fresh tool available\n'
EOF

chmod +x "$fake_bin/mise" "$managed_bin/fresh-tool"

export HOME="$TMP_DIR/home"
export DOTFILES="$ROOT_DIR"
export HOMEBREW_PREFIX="$TMP_DIR/homebrew"
export MISE_TEST_MANAGED_BIN="$managed_bin"
export MISE_TEST_JAVA_HOME="$TMP_DIR/mise/installs/java/latest"
export PATH="$fake_bin:/usr/bin:/bin"
fresh_terminal_path="$PATH"

# shellcheck source=tools/lib.sh
source "$ROOT_DIR/tools/lib.sh"

! command -v fresh-tool >/dev/null 2>&1 ||
  fail "fresh terminal unexpectedly contained the newly installed command"

load_mise_environment

[[ "$(command -v fresh-tool)" == "$managed_bin/fresh-tool" ]] ||
  fail "mise command was not added to the active Bootstrapper environment"
[[ "${JAVA_HOME:-}" == "$MISE_TEST_JAVA_HOME" ]] ||
  fail "mise environment variables were not loaded into the Bootstrapper"

export PATH="$fresh_terminal_path"
unset JAVA_HOME
hash -r
export DOTFILES_INSTALL_NO_MAIN=true
# shellcheck source=install.sh
source "$ROOT_DIR/install.sh"
TOOLS_LIB_LOADED=true
bootstrap_tool_log="$TMP_DIR/bootstrap-tools.log"

# Called indirectly by run_tool_installers from the sourced Bootstrapper.
# shellcheck disable=SC2329
run_tool() {
  local tool="$1"

  if [[ "$tool" == mise ]]; then
    ! command -v fresh-tool >/dev/null 2>&1 ||
      fail "fresh tool was available before the mise Tool Installer"
  else
    command -v fresh-tool >/dev/null 2>&1 ||
      fail "$tool ran before the Bootstrapper loaded the mise environment"
    [[ "${JAVA_HOME:-}" == "$MISE_TEST_JAVA_HOME" ]] ||
      fail "$tool did not inherit mise environment variables"
  fi

  printf '%s\n' "$tool" >>"$bootstrap_tool_log"
}

run_tool_installers

[[ "$(head -n 1 "$bootstrap_tool_log")" == mise ]] ||
  fail "Bootstrapper did not establish mise before other Tool Installers"

printf 'mise environment test: passed\n'
