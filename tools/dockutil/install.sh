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
  "$dockutil" --remove "$item" --no-restart
done

# Add frequently used applications to the Dock
app_exists Ghostty && "$dockutil" --add "/Applications/Ghostty.app" --after "com.apple.Notes" --no-restart
app_exists Zed && "$dockutil" --add "/Applications/Zed.app" --after "com.apple.Notes" --no-restart
app_exists Cursor && "$dockutil" --add "/Applications/Cursor.app" --after "com.apple.Notes" --no-restart
app_exists "Brave Browser" && "$dockutil" --add "/Applications/Brave Browser.app" --after "com.apple.Notes" --no-restart
app_exists BusyCal && "$dockutil" --add "/Applications/BusyCal.app" --after "com.apple.MobileSMS" --no-restart

# Restart affected services to apply changes immediately
killall -9 SystemUIServer
killall -9 Dock
killall Finder
