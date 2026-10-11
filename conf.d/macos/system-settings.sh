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
