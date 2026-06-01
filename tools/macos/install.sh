#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

# ~/.macos — https://mths.be/macos

close_system_settings() {
  # Close any open System Settings panes, to prevent them from overriding
  # settings we're about to change
  osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true
}

set_scutil_name() {
  local key="$1"
  local value="$2"
  local current=""

  current="$(/usr/sbin/scutil --get "$key" 2>/dev/null || true)"
  if [[ "$current" == "$value" ]]; then
    return
  fi

  sudo /usr/sbin/scutil --set "$key" "$value"
}

configure_hostname() {
  local hostname="${DOTFILES_HARDWARE_HOSTNAME:-}"

  [[ -n "$hostname" ]] || return

  if [[ ! "$hostname" =~ ^[A-Za-z0-9-]+$ ]]; then
    echo "Error: invalid hardware hostname: $hostname" >&2
    exit 1
  fi

  set_scutil_name "HostName" "$hostname"
  set_scutil_name "LocalHostName" "$hostname"
  set_scutil_name "ComputerName" "$hostname"
}

configure_keyboard_input() {
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

  # Show ASCII control characters in standard text views using caret notation
  defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true

  # Set a blazingly fast keyboard repeat rate
  defaults write NSGlobalDomain KeyRepeat -int 1
  defaults write NSGlobalDomain InitialKeyRepeat -int 15

  # Disable press-and-hold for keys in favor of key repeat
  # This makes it possible to continuously repeat keys by holding them down
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

  # Enable full keyboard access for all controls
  # Improves usability by allowing keyboard shortcuts to be used for all controls
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 2
}

configure_screen_display() {
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

  # Save screenshots as PNG for lossless output and broad tooling support
  defaults write com.apple.screencapture type -string "png"

  # Disable window shadows in screenshots for cleaner documentation images
  defaults write com.apple.screencapture disable-shadow -bool true

  # Set screen saver to start before display sleep to avoid warning
  # Default screen saver start time: 15 minutes (900 seconds)
  defaults -currentHost write com.apple.screensaver idleTime -int 900
}

configure_finder_files() {
  ###############################################################################
  # Finder & Files                                                              #
  ###############################################################################

  # Allow quitting Finder via ⌘ + Q; doing so will also hide desktop icons
  defaults write com.apple.finder QuitMenuItem -bool true

  # Show all filename extensions in Finder
  # Makes file types more visible, which is helpful for developers
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  # Show hidden files in Finder for dotfiles and development directories
  defaults write com.apple.finder AppleShowAllFiles -bool true

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

  # Show Finder status bar with item counts and free space
  defaults write com.apple.finder ShowStatusBar -bool true

  # Show full POSIX path in Finder window titles
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

  # Avoid writing .DS_Store files to network volumes
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

  # Avoid writing .DS_Store files to USB volumes
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
}

configure_dock_menu_bar() {
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
}

configure_updates_security() {
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

  # Disable Apple personalized advertising
  defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false

  # Enable firewall with sensible defaults
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off --setallowsigned off --setallowsignedapp off --setstealthmode on --setglobalstate on

  # Enable FileVault disk encryption if not already enabled
  # Improves security by encrypting the entire disk
  if ! fdesetup status | grep -q "FileVault is On"; then
    sudo fdesetup enable -user "$(whoami)"
  fi
}

configure_power_management() {
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
}

configure_application_settings() {
  ###############################################################################
  # Application-Specific Settings                                               #
  ###############################################################################

  # Disable the "Are you sure you want to open this application?" dialog
  # Removes confirmation for applications downloaded from the internet
  defaults write com.apple.LaunchServices LSQuarantine -bool false

  # Increase window resize speed for Cocoa applications
  defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

  # Expand save panels by default to expose paths and advanced options
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

  # Expand print panels by default to expose advanced options
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  # Use plain text by default in TextEdit
  defaults write com.apple.TextEdit RichText -int 0

  # Use UTF-8 for TextEdit open and save operations
  defaults write com.apple.TextEdit PlainTextEncoding -int 4
  defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

  # Enable Safari developer tools
  defaults write com.apple.Safari IncludeDevelopMenu -bool true
  defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true

  # Show full URLs in Safari's address bar
  defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

  # Enable WebKit developer extras in supported web views
  defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

  # Show developer-focused crash reporter dialogs
  defaults write com.apple.CrashReporter DialogType -string "developer"

  # Prevent Time Machine from prompting to use new hard drives as backup volume
  defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

  # Add a shortcut for deleting messages in Messages. Conversation > Delete Conversation is Opt+Cmd+9
  # defaults write com.apple.MobileSMS NSUserKeyEquivalents -dict "Delete Conversation..." -string "@~9"

  # Automatically quit printer app once the print jobs complete
  defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

  # Disable send and reply animations in Mail.app
  defaults write com.apple.mail DisableReplyAnimations -bool true
  defaults write com.apple.mail DisableSendAnimations -bool true

  # Copy email addresses as plain addresses in Mail.app
  defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

  # Disable inline attachment previews in Mail.app
  defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

  # Disabling password hints on the lock screen (security improvement)
  defaults write com.apple.loginwindow RetriesUntilHint -int 0
}

configure_keyboard_shortcuts() {
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
}

configure_remote_access() {
  ###############################################################################
  # Remote Access & Management                                                  #
  ###############################################################################

  # Disable Apple Remote Desktop
  # Prevents remote management unless explicitly configured
  sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate
}

restart_affected_services() {
  ###############################################################################
  # Apply Changes & Restart Services                                            #
  ###############################################################################

  # Restart affected services to apply changes immediately
  killall -9 SystemUIServer
  killall -9 Dock
  killall Finder
}

close_system_settings
configure_hostname
configure_keyboard_input
configure_screen_display
configure_finder_files
configure_dock_menu_bar
configure_updates_security
configure_power_management
configure_application_settings
configure_keyboard_shortcuts
configure_remote_access
restart_affected_services
