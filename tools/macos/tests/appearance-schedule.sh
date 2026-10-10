#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export DOTFILES="$ROOT_DIR"
export DOTFILES_MACOS_NO_MAIN=true

# shellcheck disable=SC1090
source "$ROOT_DIR/tools/macos/install.sh"

fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/appearance-schedule.XXXXXX")"
trap 'rm -rf "$fixture_dir"' EXIT
export HOME="$fixture_dir/home with spaces"
mkdir -p "$HOME"
label="com.luisurrutia.appearance-schedule"
agent_path="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"
gui_available=true
fail_bootout=false
fail_bootstrap=false

# Keep launchd mutations outside the live session while using real Stow links.
launchctl() {
  printf '%s\n' "$*" >> "$fixture_dir/launchctl.log"
  case "$1" in
    print)
      if [[ "$2" == "$domain" ]]; then
        [[ "$gui_available" == true ]]
      else
        [[ "$2" == "$domain/$label" && -f "$fixture_dir/loaded" ]]
      fi
      ;;
    bootout)
      [[ "$fail_bootout" == false ]] || return 1
      [[ "$2" == "$domain/$label" ]] || return 1
      rm "$fixture_dir/loaded"
      ;;
    bootstrap)
      [[ "$fail_bootstrap" == false ]] || return 1
      [[ "$2" == "$domain" && "$3" == "$agent_path" && -L "$3" ]] || return 1
      /usr/bin/plutil -lint "$3"
      touch "$fixture_dir/loaded"
      ;;
    *) return 1 ;;
  esac
}

configure_appearance_schedule
[[ -L "$agent_path" && -f "$fixture_dir/loaded" ]]
configure_appearance_schedule
[[ "$(grep -c '^bootstrap ' "$fixture_dir/launchctl.log")" == 2 ]]
[[ "$(grep -c '^bootout ' "$fixture_dir/launchctl.log")" == 1 ]]

cp "$fixture_dir/launchctl.log" "$fixture_dir/before-stow-failure.log"
stow() { return 73; }
if configure_appearance_schedule > "$fixture_dir/stow-failure.log"; then
  echo 'Expected Stow failure to propagate with an existing managed link' >&2
  exit 1
else
  [[ "$?" == 73 ]]
fi
cmp "$fixture_dir/launchctl.log" "$fixture_dir/before-stow-failure.log"
[[ ! -s "$fixture_dir/stow-failure.log" ]]
if stow_config macos --fold > "$fixture_dir/stow-failure.log"; then
  echo 'Expected folded Stow failure to propagate' >&2
  exit 1
else
  [[ "$?" == 73 ]]
fi
[[ ! -s "$fixture_dir/stow-failure.log" ]]
unset -f stow

fail_bootout=true
if configure_appearance_schedule; then
  echo 'Expected unload failure to propagate' >&2
  exit 1
fi
[[ "$(grep -c '^bootstrap ' "$fixture_dir/launchctl.log")" == 2 ]]
fail_bootout=false
fail_bootstrap=true
if configure_appearance_schedule; then
  echo 'Expected load failure to propagate' >&2
  exit 1
fi
fail_bootstrap=false

gui_available=false
: > "$fixture_dir/launchctl.log"
configure_appearance_schedule
[[ ! -f "$fixture_dir/loaded" ]]
[[ "$(wc -l < "$fixture_dir/launchctl.log" | tr -d ' ')" == 1 ]]

rm "$agent_path"
printf 'Keep my configuration\n' > "$agent_path"
: > "$fixture_dir/launchctl.log"
if configure_appearance_schedule; then
  echo 'Expected unmanaged file conflict' >&2
  exit 1
fi
[[ "$(cat "$agent_path")" == 'Keep my configuration' ]]
[[ ! -s "$fixture_dir/launchctl.log" ]]
rm "$agent_path"
ln -s "$fixture_dir/missing.plist" "$agent_path"
if configure_appearance_schedule; then
  echo 'Expected foreign symlink conflict' >&2
  exit 1
fi
[[ "$(readlink "$agent_path")" == "$fixture_dir/missing.plist" ]]

python3 - "$ROOT_DIR" "$fixture_dir" <<'PY'
import json
import plistlib
import shlex
import subprocess
import sys
from pathlib import Path

root, fixture = map(Path, sys.argv[1:])
config = plistlib.loads((root / "tools/macos/config/Library/LaunchAgents/com.luisurrutia.appearance-schedule.plist").read_bytes())
assert config["StartCalendarInterval"] == [{"Hour": 10, "Minute": 0}, {"Hour": 20, "Minute": 0}]
assert config["RunAtLoad"] is True
assert config["LimitLoadToSessionType"] == "Aqua"
assert config["ProgramArguments"][:2] == ["/usr/bin/osascript", "-e"]
compiled = fixture / "schedule.scpt"
subprocess.run(["/usr/bin/osacompile", "-o", str(compiled), "-e", config["ProgramArguments"][2]], check=True)
probe = '''on run argv
    set schedule to load script POSIX file (item 1 of argv)
    return schedule's darkModeForTime((item 2 of argv) as integer)
end run'''
for seconds, expected in [(0, "true"), (35999, "true"), (36000, "false"), (71999, "false"), (72000, "true"), (86399, "true")]:
    actual = subprocess.check_output(["/usr/bin/osascript", "-e", probe, str(compiled), str(seconds)], text=True).strip()
    assert actual == expected, (seconds, actual, expected)
# Inject a denied automation event and redirect the preference write to a marker.
marker = fixture / "automatic-switching-disabled"
source = config["ProgramArguments"][2]
command = "/usr/bin/defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false"
assert source.count(command) == 1
source = source.replace(json.dumps(command), json.dumps(f"/usr/bin/touch {shlex.quote(str(marker))}"))
controller = 'tell application "System Events"'
assert source.count(controller) == 1
source = source.replace(controller, 'error "Automation denied" number -1743\n    ' + controller)
denied = subprocess.run(["/usr/bin/osascript", "-e", source], text=True, capture_output=True)
assert denied.returncode != 0 and "(-1743)" in denied.stderr, denied
assert not marker.exists(), "Automation denial disabled native automatic switching"
print("Appearance schedule: install, reload, headless login, conflicts, failures and six time boundaries passed")
PY
