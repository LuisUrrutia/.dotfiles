#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin dockutil

# Set up dock: remove default apps and add preferred ones
TO_REMOVE_FROM_DOCK=(
  "com.apple.FaceTime"
  "com.apple.mail"
  "com.apple.TV"
  "com.apple.freeform"
  "com.apple.reminders"
  "com.apple.iCal"
  "com.apple.Music"
  "com.apple.Safari"
  "com.apple.AddressBook"
  "com.apple.Maps"
  "com.apple.iWork.Keynote"
  "com.apple.iWork.Numbers"
  "com.apple.iWork.Pages"
  "Brave Browser"
  "com.brave.Browser"
)
for item in "${TO_REMOVE_FROM_DOCK[@]}"; do
  # Ignore errors if item doesn't exist
  "$bin_path" --remove "$item" --no-restart || true
done

# Add app to dock if it exists, or move it into the preferred order if present
place_in_dock() {
  local app="$1"
  local after="$2"

  if ! app_exists "$app"; then
    return 1
  fi

  if "$bin_path" --find "$app" &>/dev/null; then
    "$bin_path" --move "$app" --after "$after" --no-restart
  else
    "$bin_path" --add "/Applications/${app}.app" --after "$after" --no-restart
  fi
}

# Add frequently used applications to the Dock
anchor="com.apple.Notes"
for app in "Ghostty" "cmux" "Zed" "Cursor" "Arc"; do
  if place_in_dock "$app" "$anchor"; then
    anchor="$app"
  fi
done

if app_exists "BusyCal"; then
  place_in_dock "BusyCal" "com.apple.MobileSMS"
fi

# Restart affected services to apply changes immediately
killall -9 SystemUIServer
killall -9 Dock
killall Finder
