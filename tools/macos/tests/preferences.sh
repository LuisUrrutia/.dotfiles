#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export DOTFILES="$ROOT_DIR"
export DOTFILES_MACOS_NO_MAIN=true

# shellcheck disable=SC1090
source "$ROOT_DIR/tools/macos/install.sh"

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

# Exercise the real defaults parser while keeping writes outside live preferences.
defaults() {
  local scope=""
  if [[ "$1" == -currentHost ]]; then
    scope="ByHost/"
    mkdir -p "$fixture_dir/ByHost"
    shift
  fi
  local action="$1"
  local domain="$2"
  shift 2
  /usr/bin/defaults "$action" "$fixture_dir/$scope$domain" "$@"
}

defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 999 '
  <dict><key>enabled</key><true/><key>custom</key><string>preserve</string></dict>
'

configure_keyboard_input
configure_window_management
configure_safari_developer_tools
configure_airplay_receiver
configure_keyboard_shortcuts
cp "$fixture_dir/com.apple.symbolichotkeys.plist" "$fixture_dir/first-run.plist"
configure_keyboard_shortcuts

# Record privileged power changes without changing the host's power policy.
sudo_askpass() {
  printf '%s\n' "$*" >> "$fixture_dir/power-$battery_present.txt"
}

pmset() {
  [[ "$*" == '-g batt' ]] || return 1
  if [[ "$battery_present" == true ]]; then
    printf '%s\n' 'InternalBattery-0'
  else
    printf '%s\n' "Now drawing from 'AC Power'"
  fi
}

for battery_present in true false; do
  configure_power_management
done

python3 - "$fixture_dir" <<'PY'
import plistlib
import sys
from pathlib import Path

fixture = Path(sys.argv[1])


def read(name):
    return plistlib.loads((fixture / f"{name}.plist").read_bytes())


hotkeys = read("com.apple.symbolichotkeys")["AppleSymbolicHotKeys"]
assert hotkeys["999"] == {"enabled": True, "custom": "preserve"}
assert read("first-run") == read("com.apple.symbolichotkeys"), "rerun changed hotkeys"

table = Path("/System/Library/ExtensionKit/Extensions/KeyboardSettings.appex/Contents/Resources/en.lproj/DefaultShortcutsTable.xml")
groups = plistlib.loads(table.read_bytes())
screenshots = next(group for group in groups if group["identifier"] == "screenshots")
for shortcut in screenshots["elements"]:
    shortcut_id = str(shortcut["sybmolichotkey"])
    assert hotkeys[shortcut_id]["enabled"] is False, shortcut["name"]

shortcuts = [shortcut for group in groups for shortcut in group.get("elements", [])]
next_window = next(shortcut for shortcut in shortcuts if shortcut.get("sybmolichotkey") == 27)
hyper_modifiers = 1048576 | 524288 | 262144 | 131072
assert hotkeys["27"] == {
    "enabled": True,
    "value": {
        "type": "standard",
        "parameters": [next_window["charKey"], next_window["key"], hyper_modifiers],
    },
}
assert hotkeys["60"]["enabled"] is False
assert hotkeys["61"]["enabled"] is False

global_settings = read("NSGlobalDomain")
assert global_settings["NSAutomaticInlinePredictionEnabled"] is False
assert global_settings["AppleSpacesSwitchOnActivate"] is False
assert global_settings["AppleActionOnDoubleClick"] == "Fill"
assert read("com.apple.dock")["mru-spaces"] is False
windows = read("com.apple.WindowManager")
assert windows["EnableStandardClickToShowDesktop"] is False
assert windows["EnableTiledWindowMargins"] is False
safari = read("com.apple.Safari")
assert safari["IncludeDevelopMenu"] is True
assert safari["WebKitDeveloperExtrasEnabledPreferenceKey"] is True
assert safari["com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled"] is True
assert safari["ShowFullURLInSmartSearchField"] is True
assert safari["AutoOpenSafeDownloads"] is False
assert safari["WebKitTabToLinksPreferenceKey"] is True
assert safari["com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks"] is True
assert read("ByHost/com.apple.controlcenter")["AirplayReceiverEnabled"] is False
assert not (fixture / "com.apple.controlcenter.plist").exists()

for battery in ("true", "false"):
    commands = (fixture / f"power-{battery}.txt").read_text().splitlines()
    settings = {}
    for command in commands:
        executable, source, key, value = command.split()
        assert executable == "pmset"
        settings[source, key] = int(value)
    assert 0 < settings["-c", "displaysleep"] < settings["-c", "sleep"]
    if battery == "true":
        assert settings["-b", "displaysleep"] == 10
        assert settings["-b", "sleep"] == 15
    else:
        assert not any(source == "-b" for source, _ in settings)
print(f"macOS preferences test: passed ({len(screenshots['elements'])} screenshot shortcuts)")
PY
