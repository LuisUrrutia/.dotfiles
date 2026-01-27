#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin dockutil
dockutil="$bin_path"

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
)
for item in "${TO_REMOVE_FROM_DOCK[@]}"; do
  # Ignore errors if item doesn't exist
  "$dockutil" --remove "$item" --no-restart || true
done

# Add app to dock if it exists and isn't already there
add_to_dock() {
  local app="$1"
  local after="$2"
  app_exists "$app" && ! "$dockutil" --find "$app" &>/dev/null &&
    "$dockutil" --add "/Applications/${app}.app" --after "$after" --no-restart
}

# Add frequently used applications to the Dock
add_to_dock "Ghostty" "com.apple.Notes"
add_to_dock "Zed" "com.apple.Notes"
add_to_dock "Cursor" "com.apple.Notes"
add_to_dock "Brave Browser" "com.apple.Notes"
add_to_dock "BusyCal" "com.apple.MobileSMS"

# Restart affected services to apply changes immediately
killall -9 SystemUIServer
killall -9 Dock
killall Finder
