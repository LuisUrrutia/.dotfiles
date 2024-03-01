#!/usr/bin/env bash

# ~/.macos — https://mths.be/macos

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.macos` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &


# Disable automatic capitalization as it’s annoying when typing code
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic period substitution as it’s annoying when typing code
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Set a blazingly fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Enable subpixel font rendering on non-Apple LCDs
defaults write NSGlobalDomain AppleFontSmoothing -int 2

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Allow quitting Finder via ⌘ + Q; doing so will also hide desktop icons
defaults write com.apple.finder QuitMenuItem -bool true

# Show all filename extensions in Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Empty Trash securely by default
defaults write com.apple.finder EmptyTrashSecurely -bool true

# Show the ~/Library folder
chflags nohidden ~/Library

softwareupdate --schedule on

# Enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Check for software updates daily, not just once per week
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# Turn on app auto-update
defaults write com.apple.commerce AutoUpdate -bool true

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Add a shortcut for deleting messages
defaults write com.apple.MobileSMS.plist NSUserKeyEquivalents -dict 'Delete Conversation...' '@\U007F'

# Don’t display the annoying prompt when quitting iTerm
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

if [[ $(uname -m) != 'arm64' ]]; then
  # Switch option with command 
  hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x7000000E2,"HIDKeyboardModifierMappingDst":0x7000000E3},{"HIDKeyboardModifierMappingSrc":0x7000000E3,"HIDKeyboardModifierMappingDst":0x7000000E2}]}'
  # Reverse scroll for mouse
  defaults write -g com.apple.swipescrolldirection -bool false
fi

# Show 24 hours clock
defaults write com.apple.menuextra.clock Show24Hour -int 1

# Don't show siri in menubar
defaults write com.apple.Siri StatusMenuVisible -int 0

# Don't show spotlight in menubar
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1

# Don't rearrange Spaces
defaults write com.apple.dock "mru-spaces" -int 0

# Saves screenshots into its own folder
mkdir -p ${HOME}/Pictures/Screenshots
defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"

# Size of dock
defaults write com.apple.dock tilesize -int 55

# auto hide dock
defaults write com.apple.dock autohide -bool true

#  Disabling password hints on the lock screen
defaults write com.apple.loginwindow RetriesUntilHint -int 0


# wake the machine when the laptop lid (or clamshell) is opened
sudo pmset -a lidwake 1

# display sleep timer
sudo pmset -a displaysleep 10

# Disable machine sleep while charging
sudo pmset -c sleep 0

# Set machine sleep to 10 minutes on battery
sudo pmset -b sleep 15

# Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw \
  --setblockall off \
  --setallowsigned on \
  --setallowsignedapp on \
  --setloggingmode on \
  --setstealthmode on \
  --setglobalstate on

# disable ARD 
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate

# umask 027
sudo launchctl config user umask 027


# TODO: Check if this config works
defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool true
defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool true


killall -9 SystemUIServer
killall -9 Dock
