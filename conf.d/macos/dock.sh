#!/usr/bin/env bash
set -euo pipefail
for item in FaceTime mail TV freeform reminders iCal Music Safari AddressBook Maps iWork.Keynote iWork.Numbers iWork.Pages; do
  if dockutil --find "com.apple.$item" >/dev/null 2>&1; then
    dockutil --remove "com.apple.$item" --no-restart
  fi
done
anchor=com.apple.Notes
for app in Ghostty Zed Cursor Dia; do
  [[ -d "/Applications/$app.app" ]] || { echo "Missing Dock app: $app" >&2; exit 1; }
  if dockutil --find "$app" >/dev/null 2>&1; then
    dockutil --move "$app" --after "$anchor" --no-restart
  else
    dockutil --add "/Applications/$app.app" --after "$anchor" --no-restart
  fi
  anchor="$app"
done
