#!/usr/bin/env bash

# ~/.macos — https://mths.be/macos

# Close any open System Settings panes, to prevent them from overriding
# settings we're about to change
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

###############################################################################
# Keyboard & Input                                                            #
###############################################################################

# Disable automatic capitalization as it's annoying when typing code
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable smart dashes as they're annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic period substitution as it's annoying when typing code
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable smart quotes as they're annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Set a blazingly fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable press-and-hold for keys in favor of key repeat
# This makes it possible to continuously repeat keys by holding them down
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Enable full keyboard access for all controls
# Improves usability by allowing keyboard shortcuts to be used for all controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

###############################################################################
# Screen & Display                                                            #
###############################################################################

# Do not show desktop icons
defaults write com.apple.finder CreateDesktop -bool false

# Turn off font smoothing
# See here for why https://tonsky.me/blog/monitors/
defaults -currentHost write -g AppleFontSmoothing -int 0

# Jump to spot that's clicked when clicking on scroll bars
defaults write -g AppleScrollerPagingBehavior -int 1

# Require password immediately after sleep or screen saver begins
# Enhances security by requiring immediate authentication
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Saves screenshots into its own folder
mkdir -p "${HOME}/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"

# Set screen saver to start before display sleep to avoid warning
# Default screen saver start time: 15 minutes (900 seconds)
defaults -currentHost write com.apple.screensaver idleTime -int 900

###############################################################################
# Finder & Files                                                              #
###############################################################################

# Allow quitting Finder via ⌘ + Q; doing so will also hide desktop icons
defaults write com.apple.finder QuitMenuItem -bool true

# Show all filename extensions in Finder
# Makes file types more visible, which is helpful for developers
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Show the ~/Library folder
# Makes it easier to access application support files and configurations
chflags nohidden ~/Library

# Remove old trash items after 30 days
defaults write com.apple.finder FXRemoveOldTrashItems -bool true

# Do not show removable media on desktop
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

# Show home directory as default
defaults write com.apple.finder NewWindowTarget -string "PfHm"

# Sort folders first in Finder
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Show list view by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Search current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Show path bar at bottom of Finder windows
defaults write com.apple.finder ShowPathbar -bool true

###############################################################################
# Dock & Menu Bar                                                             #
###############################################################################

# Size of dock icons (in pixels)
defaults write com.apple.dock tilesize -int 55

# Auto hide dock to maximize screen real estate
defaults write com.apple.dock autohide -bool true

# Don't rearrange Spaces based on usage
# Keeps your workspace arrangement consistent
defaults write com.apple.dock "mru-spaces" -bool false

# Show 24 hours clock instead of 12-hour format
defaults write com.apple.menuextra.clock Show24Hour -int 1

# Don't show siri in menubar to save space
defaults write com.apple.Siri StatusMenuVisible -int 0

# Don't show spotlight in menubar
# Using Raycast instead as a more powerful alternative
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1

# Show battery percentage in menubar
defaults write ~/Library/Preferences/ByHost/com.apple.controlcenter.plist BatteryShowPercentage -bool true

###############################################################################
# System Updates & Security                                                   #
###############################################################################

# Enable automatic software update checks
softwareupdate --schedule on
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Check for software updates daily, not just once per week
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install System data files & security updates automatically
# Critical for maintaining system security
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# Turn on app auto-update for App Store apps
defaults write com.apple.commerce AutoUpdate -bool true

# Enable firewall with sensible defaults
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off --setallowsigned off --setallowsignedapp off --setstealthmode on --setglobalstate on

# Enable FileVault disk encryption if not already enabled
# Improves security by encrypting the entire disk
if ! fdesetup status | grep -q "FileVault is On"; then
  sudo fdesetup enable -user "$(whoami)"
fi

###############################################################################
# Power Management                                                            #
###############################################################################

# Wake the machine when the laptop lid is opened
sudo pmset -a lidwake 1

# Power management settings for when plugged in (AC power)
# Disable machine sleep while charging for desktop replacement mode
sudo pmset -c sleep 0
sudo pmset -c displaysleep 30

# Power management settings for battery power
# Set display sleep to happen before system sleep
sudo pmset -b displaysleep 10
sudo pmset -b sleep 15

###############################################################################
# Application-Specific Settings                                               #
###############################################################################

# Disable the "Are you sure you want to open this application?" dialog
# Removes confirmation for applications downloaded from the internet
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Add a shortcut for deleting messages in Messages. Conversation > Delete Conversation is Opt+Cmd+9
defaults write com.apple.MobileSMS NSUserKeyEquivalents -dict "Delete Conversation..." -string "@~9"

# Don't display the annoying prompt when quitting iTerm
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Disabling password hints on the lock screen (security improvement)
defaults write com.apple.loginwindow RetriesUntilHint -int 0

###############################################################################
# Keyboard Shortcuts Customization                                            #
###############################################################################

# Keyboard > Shortcuts > Spotlight > Show Spotlight search, disable
# Note: Replacing it with Raycast https://raycastapp.notion.site/Hotkey-56103210375b4fc78b63a7c5e7075fb7
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 64 "
  <dict>
    <key>enabled</key><false/>
  </dict>
"

# Keyboard > Shortcuts > Spotlight > Show Finder search window, disable
# Note: Replacing it with Raycast https://raycastapp.notion.site/Hotkey-56103210375b4fc78b63a7c5e7075fb7
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 65 "
  <dict>
    <key>enabled</key><false/>
  </dict>
"

# Keyboard > Shortcuts > Screenshots > Save picture of screen as file, disable
# Note: Replacing it with CleanShotX for better screenshot capabilities
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 28 "
  <dict>
    <key>enabled</key><false/>
  </dict>
"

# Keyboard > Shortcuts > Screenshots > Save picture of selected area as file, disable
# Note: Replacing it with CleanShotX for better screenshot capabilities
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 30 "
  <dict>
    <key>enabled</key><false/>
  </dict>
"

###############################################################################
# Remote Access & Management                                                  #
###############################################################################

# Disable Apple Remote Desktop
# Prevents remote management unless explicitly configured
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate

###############################################################################
# Apply Changes & Restart Services                                            #
###############################################################################

# Restart affected services to apply changes immediately
killall -9 SystemUIServer
killall -9 Dock
killall Finder
