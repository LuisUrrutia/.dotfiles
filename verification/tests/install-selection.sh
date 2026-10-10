#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fixture snippets are evaluated by the installer shell.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
HARDWARE_HASH=abcdef123456
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'install selection test: %s\n' "$*" >&2
  cat "$TMP_DIR/error" "$TMP_DIR/runner-error" >&2
  exit 1
}

export DOTFILES="$ROOT_DIR"
export DOTFILES_INSTALL_NO_MAIN=true
export XDG_STATE_HOME="$TMP_DIR/state"
export SELECTION_FIXTURE="$TMP_DIR"
export SELECTION_HARDWARE_HASH="$HARDWARE_HASH"
pending="$XDG_STATE_HOME/dotfiles/install-selection/$HARDWARE_HASH"
machine="$TMP_DIR/machines/$HARDWARE_HASH.sh"
mkdir -p "$TMP_DIR/machines"

cat >"$TMP_DIR/runner.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "$DOTFILES/install.sh"
MACHINES_DIR="$SELECTION_FIXTURE/machines"
LEGACY_INSTALLED_MARKER="$SELECTION_FIXTURE/legacy-installed"
uname() { printf '%s\n' Darwin; }
machash() { printf '%s\n' "$SELECTION_HARDWARE_HASH"; }
is_interactive() { [[ "${SELECTION_INTERACTIVE:-true}" == true ]]; }
load_tool_library() { :; }
prepare_install_session() { :; }
load_homebrew() { :; }
github_phase_preflight() { :; }
install_homebrew() { :; }
print_install_plan() { :; }
print_next_steps() { :; }
ask_yes_no() {
  printf '%s\n' "$1" >>"$SELECTION_FIXTURE/prompts"
  is_interactive || return 1
  case "$1" in
  'Reuse the saved tool selection from the interrupted installation?')
    [[ "${SELECTION_REUSE:-true}" == true ]] ;;
  'Create a Machine Config for this hardware using the installed tool selection?')
    [[ "${SELECTION_CREATE_MACHINE:-false}" == true ]] ;;
  'Clean up Homebrew packages not listed in the selected Brewfiles after install?')
    [[ "${SELECTION_ABORT_AFTER_CHOICES:-false}" != true ]] || kill -TERM "$$"
    return 1 ;;
  'Do you need OrbStack, Android tools, or developer GUI apps?' | \
    'Install dive (Docker image layer inspector)?' | \
    'Install Yaak'* | 'Install yaak'* | \
    'Install Go tools?' | 'Install Lua tools?')
    [[ "${SELECTION_CHOOSE_TOOLS:-true}" == true ]] ;;
  *) return 1 ;;
  esac
}
install_declared_packages_and_dependents() {
  if [[ "$ALL_PROFILES" == true ]]; then
    create_profile_brewfile "$SELECTION_FIXTURE/bundle" "${PROFILE_ORDER[@]}"
  elif ((${#SELECTED_PROFILES[@]} > 0)); then
    create_profile_brewfile "$SELECTION_FIXTURE/bundle" "${SELECTED_PROFILES[@]}"
  else
    : >"$SELECTION_FIXTURE/bundle"
  fi
  case "${SELECTION_RESULT:-success}" in
  failure) return 37 ;;
  signal) kill -TERM "$$" ;;
  esac
}
main "$@"
EOF

run_installer() {
  : >"$TMP_DIR/prompts"
  installer_status=0
  {
    /bin/bash "$TMP_DIR/runner.sh" "$@" >"$TMP_DIR/output" 2>"$TMP_DIR/error" || installer_status=$?
  } 2>"$TMP_DIR/runner-error"
}

SELECTION_RESULT=failure run_installer
[[ "$installer_status" -eq 37 ]] || fail "network failure did not propagate"
[[ -f "$pending" ]] || fail "interrupted installation lost the tool selection"
[[ ! -e "$XDG_STATE_HOME/dotfiles/installed" && ! -e "$machine" ]] ||
  fail "failed installation marked success or created a Machine Config"
cp "$TMP_DIR/bundle" "$TMP_DIR/expected-bundle"
cp "$pending" "$TMP_DIR/expected-selection"
for expected_package in 'brew "dive"' 'cask "yaak"' 'brew "go"' 'brew "lua"' 'brew "luarocks"'; do
  grep -F "$expected_package" "$TMP_DIR/expected-bundle" >/dev/null ||
    fail "initial selection omitted $expected_package"
done
for excluded_package in orbstack rustup perl cpanm; do
  if grep -F "\"$excluded_package\"" "$TMP_DIR/expected-bundle" >/dev/null; then
    fail "initial selection included declined package $excluded_package"
  fi
done

SELECTION_RESULT=failure run_installer
[[ "$installer_status" -eq 37 ]] || fail "resumed failure did not propagate"
grep -F 'Reuse the saved tool selection' "$TMP_DIR/prompts" >/dev/null ||
  fail "restart did not offer to reuse the selection"
if grep -F 'Install dive' "$TMP_DIR/prompts" >/dev/null; then
  fail "accepted recovery asked the package questions again"
fi
cmp -s "$TMP_DIR/expected-bundle" "$TMP_DIR/bundle" ||
  fail "recovery changed the package or language selection"
cmp -s "$TMP_DIR/expected-selection" "$pending" ||
  fail "a second failure lost the saved selection"

SELECTION_CREATE_MACHINE=true run_installer
[[ "$installer_status" -eq 0 ]] || fail "recovered install failed"
[[ -f "$machine" && -f "$XDG_STATE_HOME/dotfiles/installed" && ! -e "$pending" ]] ||
  fail "successful install did not create the accepted profile and clear pending state"
run_installer
[[ "$installer_status" -eq 0 ]] || fail "generated Machine Config could not be loaded"
cmp -s "$TMP_DIR/expected-bundle" "$TMP_DIR/bundle" ||
  fail "Machine Config expanded individually selected packages or languages"
if grep -F 'Create a Machine Config' "$TMP_DIR/prompts" >/dev/null; then
  fail "registered hardware was offered an overwrite"
fi
cp "$machine" "$TMP_DIR/expected-machine"

SELECTION_RESULT=failure run_installer --profile audio
[[ "$installer_status" -eq 37 ]] || fail "explicit selection did not reach installation"
if grep -F 'Reuse the saved tool selection' "$TMP_DIR/prompts" >/dev/null; then
  fail "explicit profiles offered recovery"
fi
grep -F 'cask "loopback"' "$TMP_DIR/bundle" >/dev/null ||
  fail "explicit profiles did not override the Machine Config"
cp "$pending" "$TMP_DIR/explicit-selection"

run_installer --dry-run
[[ "$installer_status" -eq 0 ]] || fail "dry run failed"
cmp -s "$TMP_DIR/explicit-selection" "$pending" || fail "dry run changed recovery state"
if grep -F 'Reuse the saved tool selection' "$TMP_DIR/prompts" >/dev/null; then
  fail "dry run offered recovery"
fi

SELECTION_INTERACTIVE=false run_installer
[[ "$installer_status" -eq 0 ]] || fail "unattended machine install failed"
cmp -s "$TMP_DIR/expected-bundle" "$TMP_DIR/bundle" ||
  fail "unattended installation reused pending choices instead of machine defaults"
cmp -s "$TMP_DIR/explicit-selection" "$pending" ||
  fail "unattended installation changed recovery state"

run_installer
[[ "$installer_status" -eq 0 ]] || fail "pending selection did not override machine defaults"
grep -F 'cask "loopback"' "$TMP_DIR/bundle" >/dev/null ||
  fail "accepted recovery used machine defaults instead of the saved selection"
cmp -s "$TMP_DIR/expected-machine" "$machine" || fail "existing Machine Config was overwritten"

rm "$machine"
SELECTION_RESULT=signal run_installer
[[ "$installer_status" -eq 143 && -f "$pending" ]] ||
  fail "SIGTERM lost the selection or did not propagate"
if grep -F 'Create a Machine Config' "$TMP_DIR/prompts" >/dev/null; then
  fail "interrupted installation offered a Machine Config"
fi
SELECTION_REUSE=false SELECTION_CHOOSE_TOOLS=false SELECTION_RESULT=failure run_installer
[[ "$installer_status" -eq 37 && ! -s "$TMP_DIR/bundle" ]] ||
  fail "declining recovery did not replace the selection with new answers"
grep -Fx 'mode=core' "$pending" >/dev/null || fail "new selection was not saved"

SELECTION_CREATE_MACHINE=false run_installer
[[ "$installer_status" -eq 0 && ! -e "$machine" && ! -e "$pending" ]] ||
  fail "declining Machine Config creation did not finish and clear recovery state"
grep -F 'Create a Machine Config' "$TMP_DIR/prompts" >/dev/null ||
  fail "successful unregistered installation did not offer a Machine Config"

for install_mode in core all; do
  install_flag=--core-only
  [[ "$install_mode" != all ]] || install_flag=--all-profiles
  SELECTION_CREATE_MACHINE=true run_installer "$install_flag"
  [[ "$installer_status" -eq 0 && -f "$machine" ]] || fail "$install_mode profile creation failed"
  grep -Fx "MACHINE_INSTALL_MODE=$install_mode" "$machine" >/dev/null ||
    fail "Machine Config did not preserve $install_mode mode"
  run_installer
  [[ "$installer_status" -eq 0 ]] || fail "$install_mode Machine Config did not load"
  if [[ "$install_mode" == core ]]; then
    [[ ! -s "$TMP_DIR/bundle" ]] || fail "core Machine Config installed optional packages"
  else
    grep -F 'cask "loopback"' "$TMP_DIR/bundle" >/dev/null ||
      fail "all Machine Config lost a profile"
    grep -F 'brew "cpanm"' "$TMP_DIR/bundle" >/dev/null ||
      fail "all Machine Config lost a language"
  fi
  rm "$machine"
done

mkdir -p "$(dirname "$pending")"
printf 'version=1\nmode=selected\nprofiles=dev\nlanguages=\npackages=dev:removed-package\n' >"$pending"
run_installer
[[ "$installer_status" -eq 0 ]] || fail "stale selection prevented a fresh installation"
grep -F 'Saved tool selection is invalid' "$TMP_DIR/output" >/dev/null ||
  fail "stale selection was not explained"
cmp -s "$TMP_DIR/expected-bundle" "$TMP_DIR/bundle" || fail "stale selection changed fresh answers"

printf 'version=1\nmode=core\nprofiles=\nlanguages=\npackages=\n' >"$pending"
printf 'touch "%s"\n' "$TMP_DIR/executed-state" >>"$pending"
run_installer
[[ "$installer_status" -eq 0 && ! -e "$TMP_DIR/executed-state" ]] ||
  fail "recovery state was executed as shell code"

cp "$TMP_DIR/expected-selection" "$pending"
SELECTION_HARDWARE_HASH=123456abcdef SELECTION_CREATE_MACHINE=false run_installer
[[ "$installer_status" -eq 0 ]] || fail "second hardware install failed"
if grep -F 'Reuse the saved tool selection' "$TMP_DIR/prompts" >/dev/null; then
  fail "another hardware hash reused this hardware's state"
fi
cmp -s "$TMP_DIR/expected-selection" "$pending" || fail "another hardware hash removed pending state"
SELECTION_HARDWARE_HASH=111111111111 run_installer --dry-run --all-profiles
[[ "$installer_status" -eq 0 && ! -e "$XDG_STATE_HOME/dotfiles/install-selection/111111111111" &&
  ! -e "$TMP_DIR/machines/111111111111.sh" ]] || fail "dry run created selection or machine state"

SELECTION_CREATE_MACHINE=true run_installer --core-only
[[ "$installer_status" -eq 0 ]] || fail "explicit core mode did not override pending state"
if grep -F 'Reuse the saved tool selection' "$TMP_DIR/prompts" >/dev/null; then
  fail "explicit core mode offered recovery"
fi
rm "$machine"
ln -s "$TMP_DIR/nonexistent-machine-target" "$machine"
SELECTION_CREATE_MACHINE=true run_installer --core-only
[[ "$installer_status" -eq 0 && -L "$machine" && ! -e "$TMP_DIR/nonexistent-machine-target" ]] ||
  fail "Machine Config creation wrote through a foreign symlink"

SELECTION_HARDWARE_HASH='' run_installer --core-only
[[ "$installer_status" -eq 0 ]] || fail "missing hardware hash prevented installation"
grep -F 'Cannot create a Machine Config' "$TMP_DIR/output" >/dev/null ||
  fail "missing hardware hash was not explained"

SELECTION_HARDWARE_HASH=222222222222 SELECTION_ABORT_AFTER_CHOICES=true run_installer
[[ "$installer_status" -eq 143 && -f "$XDG_STATE_HOME/dotfiles/install-selection/222222222222" ]] ||
  fail "interruption at the cleanup question lost the completed tool selection"

(
  # shellcheck disable=SC1090,SC1091
  source "$ROOT_DIR/install.sh"
  init_profile_order
  DETECTED_HARDWARE_HASH="$HARDWARE_HASH"
  is_interactive() { return 0; }
  apply_install_selection selected dev,languages go,lua dev:dive,dev:yaak
  save_install_selection >/dev/null
  cp "$pending" "$TMP_DIR/before-failed-save"
  mv() { return 1; }

  if save_install_selection >/dev/null; then
    fail "failed state replacement did not report failure"
  fi
  cmp -s "$TMP_DIR/before-failed-save" "$pending" || fail "failed save destroyed the last complete selection"
)

printf 'Install selection tests passed.\n'
