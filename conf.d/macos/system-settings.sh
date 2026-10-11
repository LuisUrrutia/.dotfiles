#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || exit 0
sudo -n /usr/bin/true

chflags nohidden "$HOME/Library"
sudo -n softwareupdate --schedule on
# Mise's native defaults support user preferences, not system domains.
for key in AutomaticDownload ConfigDataInstall CriticalUpdateInstall; do
  sudo -n defaults write /Library/Preferences/com.apple.SoftwareUpdate "$key" -bool true
done
sudo -n /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off --setallowsigned off --setallowsignedapp off --setstealthmode on --setglobalstate on
sudo -n pmset -a lidwake 1
sudo -n pmset -c sleep 45 displaysleep 30
if pmset -g batt | grep -q InternalBattery; then
  sudo -n pmset -b displaysleep 10 sleep 15
fi
sudo -n /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate

if ! fdesetup status | grep -q 'FileVault is On'; then
  echo 'Enable FileVault in System Settings and store its recovery key in 1Password.' >&2
  exit 1
fi
if ! sysadminctl -screenLock status 2>&1 | grep -q 'delay is 0 seconds'; then
  echo 'Set Require password after screen saver or display is turned off to Immediately in System Settings.' >&2
  exit 1
fi
