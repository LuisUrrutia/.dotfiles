#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by fake commands.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
FIXTURE_ROOT="$TMP_DIR/repository"
FAKE_BIN="$TMP_DIR/bin"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'update test: %s\n' "$*" >&2
  exit 1
}

assert_log_order() {
  local log_file="$1"
  shift
  local expected=""
  local line=0
  local previous=0

  for expected in "$@"; do
    line="$(grep -nF "$expected" "$log_file" | head -1 | cut -d: -f1)"
    [[ -n "$line" && "$line" -gt "$previous" ]] || fail "Update target order changed at: $expected"
    previous="$line"
  done
}

mkdir -p "$FIXTURE_ROOT/cli" "$FIXTURE_ROOT/maintenance" "$FIXTURE_ROOT/tools/fish" "$FAKE_BIN"
cp "$ROOT_DIR/dotfiles" "$FIXTURE_ROOT/dotfiles"
cp "$ROOT_DIR"/cli/*.sh "$FIXTURE_ROOT/cli/"
cp "$ROOT_DIR/maintenance/update.sh" "$FIXTURE_ROOT/maintenance/update.sh"
chmod +x "$FIXTURE_ROOT/dotfiles" "$FIXTURE_ROOT/maintenance/update.sh"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "claude completion check\n" >>"$UPDATE_LOG"' \
  '[[ "${UPDATE_SCENARIO:-}" != completion-drift ]]' \
  >"$FIXTURE_ROOT/tools/fish/check-claude-completion.sh"
chmod +x "$FIXTURE_ROOT/tools/fish/check-claude-completion.sh"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'tool="$(basename "$0")"' \
  'printf "%s %s\n" "$tool" "$*" >>"$UPDATE_LOG"' \
  'printf "child stdout: %s %s\n" "$tool" "$*"' \
  'printf "child stderr: %s %s\n" "$tool" "$*" >&2' \
  'if [[ "${UPDATE_SCENARIO:-}" == brew-needs-terminal && "$tool" == brew && "${1:-}" == upgrade ]] && { [[ ! -t 0 ]] || ! : </dev/tty 2>/dev/null; }; then printf "sudo: a terminal is required to read the password\n" >&2; exit 1; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == "brew-${1:-}-fails" && "$tool" == brew ]]; then exit 7; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == brew-cleanup-fails && "$tool" == brew && "${1:-}" == cleanup ]]; then exit 7; fi' \
  'if [[ "$tool" == brew && "${1:-}" == doctor && ! -f "$EXPECTED_BREW_STAMP" ]]; then exit 10; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == doctor-fails && "$tool" == brew && "${1:-}" == doctor ]]; then exit 8; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == "mise-${1:-}-fails" && "$tool" == mise ]]; then exit 9; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == nvim-plugins-fails && "$tool" == nvim && "$*" == *Lazy* ]]; then exit 11; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == nvim-blink-fails && "$tool" == nvim && "$*" == *config.blink* ]]; then exit 15; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == nvim-lsp-fails && "$tool" == nvim && "$*" == *config.lsp* ]]; then exit 16; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == nvim-parsers-fails && "$tool" == nvim && "$*" == *treesitter* ]]; then exit 12; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == skills-list-warns && "$tool" == skills && "${1:-}" == list ]]; then exit 13; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == rustup-fails && "$tool" == rustup ]]; then exit 14; fi' \
  'if [[ "${UPDATE_SCENARIO:-}" == signal && "$tool" == brew && "${1:-}" == update ]]; then' \
  '  trap '\''printf "TERM\n" >"$SIGNAL_RESULT"; exit 143'\'' TERM' \
  '  /bin/sleep 30 &' \
  '  signal_child=$!' \
  '  printf "ready %s\n" "$signal_child" >"$SIGNAL_READY"' \
  '  wait "$signal_child"' \
  'fi' \
  'exit 0' \
  >"$FAKE_BIN/fake-tool"
chmod +x "$FAKE_BIN/fake-tool"
for tool in brew mise claude rustup mas nvim skills tpack tldr mo fish; do
  ln -s fake-tool "$FAKE_BIN/$tool"
done

run_scenario() {
  local scenario="$1"
  local scenario_dir="$TMP_DIR/$scenario"
  local home_dir="$scenario_dir/home"
  local state_dir="$scenario_dir/state"
  local log_file="$scenario_dir/tools.log"
  local output_file="$scenario_dir/output.log"

  mkdir -p "$home_dir/.config/fish/functions" "$home_dir/.config/tlrc" "$state_dir"
  : >"$home_dir/.config/fish/fish_plugins"
  : >"$home_dir/.config/fish/functions/fisher.fish"
  : >"$home_dir/.config/tlrc/config.toml"
  : >"$log_file"

  set +e
  HOME="$home_dir" \
    XDG_CONFIG_HOME="$home_dir/.config" \
    XDG_STATE_HOME="$state_dir" \
    PATH="$FAKE_BIN:/usr/bin:/bin" \
    UPDATE_LOG="$log_file" \
    UPDATE_SCENARIO="$scenario" \
    EXPECTED_BREW_STAMP="$state_dir/dotfiles/update/brew" \
    "$FIXTURE_ROOT/dotfiles" update --ignore-schedule \
    >"$output_file" 2>&1
  SCENARIO_STATUS=$?
  set -e

  SCENARIO_STATE="$state_dir"
  SCENARIO_LOG="$(<"$log_file")"
  SCENARIO_OUTPUT="$(<"$output_file")"
}

run_terminal_scenario() {
  local scenario="$1"
  local scenario_dir="$TMP_DIR/$scenario"
  local home_dir="$scenario_dir/home"
  local state_dir="$scenario_dir/state"
  local log_file="$scenario_dir/tools.log"
  local output_file="$scenario_dir/output.log"

  mkdir -p "$home_dir/.config/fish/functions" "$home_dir/.config/tlrc" "$state_dir"
  : >"$home_dir/.config/fish/fish_plugins"
  : >"$home_dir/.config/fish/functions/fisher.fish"
  : >"$home_dir/.config/tlrc/config.toml"
  : >"$log_file"

  set +e
  HOME="$home_dir" \
    XDG_CONFIG_HOME="$home_dir/.config" \
    XDG_STATE_HOME="$state_dir" \
    PATH="$FAKE_BIN:/usr/bin:/bin" \
    UPDATE_LOG="$log_file" \
    UPDATE_SCENARIO="$scenario" \
    EXPECTED_BREW_STAMP="$state_dir/dotfiles/update/brew" \
    /usr/bin/script -q /dev/null "$FIXTURE_ROOT/dotfiles" update --ignore-schedule \
    >"$output_file" 2>&1
  SCENARIO_STATUS=$?
  set -e

  SCENARIO_STATE="$state_dir"
  SCENARIO_LOG="$(<"$log_file")"
  SCENARIO_OUTPUT="$(<"$output_file")"
}

run_scenario doctor-fails
[[ "$SCENARIO_STATUS" -eq 0 ]] || fail "advisory Doctor failure failed Update"
[[ -f "$SCENARIO_STATE/dotfiles/update/brew" ]] || fail "Homebrew stamp was not written before Doctor"
[[ "$SCENARIO_OUTPUT" == *'[update] Homebrew: warning (doctor failed; maintenance completed)'* ]] ||
  fail "Doctor warning outcome is missing"

for brew_stage in update upgrade autoremove cleanup; do
  run_scenario "brew-$brew_stage-fails"
  [[ "$SCENARIO_STATUS" -eq 1 ]] || fail "Homebrew $brew_stage failure did not fail Update"
  [[ ! -e "$SCENARIO_STATE/dotfiles/update/brew" ]] || fail "failed Homebrew $brew_stage chain wrote a stamp"
  [[ "$SCENARIO_LOG" == *'mise upgrade --yes'* ]] || fail "Homebrew $brew_stage failure stopped mise"
  case "$brew_stage" in
  update)
    [[ "$SCENARIO_LOG" != *'brew upgrade'* ]] || fail "Homebrew upgrade ran after update failure"
    ;;
  upgrade)
    [[ "$SCENARIO_LOG" != *'brew autoremove'* ]] || fail "Homebrew autoremove ran after upgrade failure"
    ;;
  autoremove)
    [[ "$SCENARIO_LOG" != *'brew cleanup'* ]] || fail "Homebrew cleanup ran after autoremove failure"
    ;;
  cleanup)
    [[ "$SCENARIO_LOG" != *'brew doctor'* ]] || fail "Homebrew Doctor ran after cleanup failure"
    ;;
  esac
  [[ "$SCENARIO_OUTPUT" == *"[update] Homebrew: failed ($brew_stage, status 7)"* ]] ||
    fail "Homebrew $brew_stage failure stage is missing"
done

for mise_stage in upgrade prune; do
  run_scenario "mise-$mise_stage-fails"
  [[ "$SCENARIO_STATUS" -eq 1 ]] || fail "mise $mise_stage failure did not fail Update"
  if [[ "$mise_stage" == upgrade ]]; then
    [[ "$SCENARIO_LOG" != *'mise prune --yes'* ]] || fail "mise prune ran after upgrade failure"
  fi
  [[ "$SCENARIO_LOG" == *'rustup update'* ]] || fail "mise $mise_stage failure stopped rustup"
done

for nvim_stage in plugins blink lsp parsers; do
  run_scenario "nvim-$nvim_stage-fails"
  [[ "$SCENARIO_STATUS" -eq 1 ]] || fail "Neovim $nvim_stage failure did not fail Update"
  if [[ "$nvim_stage" == plugins ]]; then
    [[ "$SCENARIO_LOG" != *config.blink* ]] || fail "blink.cmp verification ran after plugin failure"
  elif [[ "$nvim_stage" == blink ]]; then
    [[ "$SCENARIO_LOG" != *config.lsp* ]] || fail "Mason update ran after blink.cmp failure"
  elif [[ "$nvim_stage" == lsp ]]; then
    [[ "$SCENARIO_LOG" != *treesitter* ]] || fail "Neovim parsers ran after Mason failure"
  fi
  [[ "$SCENARIO_LOG" == *'skills update --yes'* ]] || fail "Neovim $nvim_stage failure stopped Skills"
done

run_scenario all-pass
[[ "$SCENARIO_STATUS" -eq 0 ]] || fail "successful Update failed"
assert_log_order "$TMP_DIR/all-pass/tools.log" \
  'brew update' \
  'brew upgrade' \
  'brew autoremove' \
  'brew cleanup --prune=all' \
  'brew doctor' \
  'mise upgrade --yes' \
  'mise prune --yes' \
  'claude completion check' \
  'rustup update' \
  'mas upgrade' \
  'nvim --headless +Lazy! sync +qa' \
  "nvim --headless +lua if not require('config.blink').ensure() then vim.cmd.cquit() end +qa" \
  "nvim --headless +lua if not require('config.lsp').update() then vim.cmd.cquit() end +qa" \
  "nvim --headless +lua require('config.treesitter').install() +qa" \
  'skills list -g' \
  'skills update --yes' \
  'tpack update all' \
  'tldr --config' \
  'mo clean' \
  'fish --no-config --command'
[[ "$SCENARIO_OUTPUT" == *'[update] Homebrew: completed'* ]] || fail "Homebrew completion is missing"
[[ "$SCENARIO_OUTPUT" == *'child stdout: rustup update'* ]] || fail "child stdout was not streamed"
[[ "$SCENARIO_OUTPUT" == *'child stderr: rustup update'* ]] || fail "child stderr was not streamed"
[[ -f "$SCENARIO_STATE/dotfiles/update/mole-clean" ]] || fail "Mole success did not write its stamp"

run_terminal_scenario brew-needs-terminal
[[ "$SCENARIO_STATUS" -eq 0 ]] || fail "Homebrew could not use the terminal for sudo"
[[ "$SCENARIO_LOG" == *'brew upgrade'* ]] || fail "terminal Homebrew upgrade did not run"

run_scenario completion-drift
[[ "$SCENARIO_STATUS" -eq 0 ]] || fail "Claude completion drift failed Software Maintenance"
[[ "$SCENARIO_OUTPUT" == *'[update] mise: warning (Claude completion drift; maintenance completed)'* ]] ||
  fail "Claude completion drift warning is missing"
[[ "$SCENARIO_LOG" == *'rustup update'* ]] || fail "Claude completion drift stopped independent targets"

run_scenario skills-list-warns
[[ "$SCENARIO_STATUS" -eq 0 ]] || fail "Skills listing warning became a failure"
[[ "$SCENARIO_LOG" != *'skills update --yes'* ]] || fail "Skills update ran after listing warning"
[[ "$SCENARIO_OUTPUT" == *'[update] Skills: warning (unable to list installed skills)'* ]] ||
  fail "Skills warning outcome is missing"

run_scenario rustup-fails
[[ "$SCENARIO_STATUS" -eq 1 ]] || fail "representative independent failure did not fail aggregate"
[[ "$SCENARIO_LOG" == *'mas upgrade'* && "$SCENARIO_LOG" == *'fish --no-config --command'* ]] ||
  fail "independent failure stopped later targets"

stamp_home="$TMP_DIR/stamp-failure/home"
stamp_state="$TMP_DIR/stamp-failure/not-a-directory"
stamp_log="$TMP_DIR/stamp-failure.log"
mkdir -p "$stamp_home"
printf 'block state directory\n' >"$stamp_state"
: >"$stamp_log"
set +e
HOME="$stamp_home" XDG_STATE_HOME="$stamp_state" PATH="$FAKE_BIN:/usr/bin:/bin" \
  UPDATE_LOG="$stamp_log" UPDATE_SCENARIO=stamp-failure \
  EXPECTED_BREW_STAMP="$stamp_state/dotfiles/update/brew" \
  "$FIXTURE_ROOT/dotfiles" update --ignore-schedule \
  >"$TMP_DIR/stamp-failure.out" 2>"$TMP_DIR/stamp-failure.err"
stamp_status=$?
set -e
[[ "$stamp_status" -eq 1 ]] || fail "state-stamp failure did not fail Update"
grep -qF '[update] Homebrew: failed (state stamp)' "$TMP_DIR/stamp-failure.out" ||
  fail "Homebrew stamp failure was not reported"
[[ "$(<"$stamp_log")" != *'brew doctor'* ]] || fail "Doctor ran after Homebrew stamp failure"
[[ "$(<"$stamp_log")" == *'mise upgrade --yes'* ]] || fail "stamp failure stopped independent targets"

missing_home="$TMP_DIR/missing/home"
missing_state="$TMP_DIR/missing/state"
mkdir -p "$missing_home" "$missing_state"
PATH="/usr/bin:/bin" HOME="$missing_home" XDG_STATE_HOME="$missing_state" \
  "$FIXTURE_ROOT/dotfiles" update >"$TMP_DIR/missing.out"
for expected in Homebrew mise rustup 'App Store' Neovim Skills 'TPack plugins' 'tlrc pages' 'Mole clean' 'Fish plugins'; do
  grep -qF "[update] $expected: skipped" "$TMP_DIR/missing.out" || fail "missing $expected was not skipped"
done

schedule_home="$TMP_DIR/schedule/home"
schedule_state="$TMP_DIR/schedule/state"
schedule_log="$TMP_DIR/schedule.log"
mkdir -p "$schedule_home/.config/fish/functions" "$schedule_state/dotfiles/update"
: >"$schedule_home/.config/fish/fish_plugins"
: >"$schedule_home/.config/fish/functions/fisher.fish"
touch "$schedule_state/dotfiles/update/brew" "$schedule_state/dotfiles/update/mole-clean"
: >"$schedule_log"
HOME="$schedule_home" XDG_STATE_HOME="$schedule_state" PATH="$FAKE_BIN:/usr/bin:/bin" \
  UPDATE_LOG="$schedule_log" UPDATE_SCENARIO=schedule \
  EXPECTED_BREW_STAMP="$schedule_state/dotfiles/update/brew" \
  "$FIXTURE_ROOT/dotfiles" update >"$TMP_DIR/schedule.out" 2>&1
[[ "$(<"$schedule_log")" != *'brew update'* ]] || fail "daily gate did not skip Homebrew"
[[ "$(<"$schedule_log")" != *'mo clean'* ]] || fail "weekly gate did not skip Mole"

legacy_home="$TMP_DIR/legacy/home"
legacy_state="$TMP_DIR/legacy/state"
legacy_log="$TMP_DIR/legacy.log"
mkdir -p "$legacy_home" "$legacy_state/dotfiles/upd"
touch "$legacy_state/dotfiles/upd/brew"
: >"$legacy_log"
HOME="$legacy_home" XDG_STATE_HOME="$legacy_state" PATH="$FAKE_BIN:/usr/bin:/bin" \
  UPDATE_LOG="$legacy_log" UPDATE_SCENARIO=legacy \
  EXPECTED_BREW_STAMP="$legacy_state/dotfiles/update/brew" \
  "$FIXTURE_ROOT/dotfiles" update >"$TMP_DIR/legacy.out" 2>&1
[[ "$(<"$legacy_log")" == *'brew update'* ]] || fail "legacy updater stamp was not ignored"

signal_home="$TMP_DIR/signal/home"
signal_state="$TMP_DIR/signal/state"
signal_ready="$TMP_DIR/signal.ready"
signal_result="$TMP_DIR/signal.result"
mkfifo "$signal_ready"
mkdir -p "$signal_home" "$signal_state"
PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$signal_home" XDG_STATE_HOME="$signal_state" \
  UPDATE_LOG="$TMP_DIR/signal.log" UPDATE_SCENARIO=signal \
  EXPECTED_BREW_STAMP="$signal_state/dotfiles/update/brew" \
  SIGNAL_READY="$signal_ready" SIGNAL_RESULT="$signal_result" \
  "$FIXTURE_ROOT/dotfiles" update --ignore-schedule >"$TMP_DIR/signal.out" 2>&1 &
signal_coordinator_pid=$!
IFS=' ' read -r signal_message signal_child_pid <"$signal_ready"
[[ "$signal_message" == ready ]] || fail "signal fixture did not start the active child"
kill -TERM "$signal_coordinator_pid"
set +e
wait "$signal_coordinator_pid"
signal_status=$?
set -e
[[ "$signal_status" -eq 143 ]] || fail "Update did not preserve TERM status"
[[ "$(<"$signal_result")" == TERM ]] || fail "Update did not forward TERM to the active child"
if kill -0 "$signal_child_pid" 2>/dev/null; then
  fail "Update left an active grandchild after TERM"
fi
