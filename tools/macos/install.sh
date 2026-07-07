#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

macos_error_count=0
macos_step_failed=0
macos_last_error=""
macos_error_log="${DOTFILES_MACOS_ERROR_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/macos-install.log}"
macos_failed_steps=()
macos_skipped_settings=()

setup_macos_error_log() {
  local log_dir

  log_dir="$(dirname "$macos_error_log")"
  if mkdir -p "$log_dir" && : >>"$macos_error_log"; then
    printf '\n[%s] Starting macOS setup\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$macos_error_log"
    exec 3>&2
    exec 2> >(tee -a "$macos_error_log" >&3)
    echo "Logging macOS setup errors to $macos_error_log" >&2
  else
    echo "Warning: unable to write macOS setup error log at $macos_error_log" >&2
    macos_error_log=""
  fi
}

log_macos_command_error() {
  local step_name="$1"
  local status="$2"
  local command="$3"
  local message

  command="${command//$'\n'/ }"
  message="Warning: macOS setup step '$step_name' failed with exit $status: $command"

  if [[ "$macos_last_error" == "$message" ]]; then
    return 0
  fi

  macos_last_error="$message"
  macos_step_failed=1
  macos_error_count=$((macos_error_count + 1))
  echo "$message" >&2
}

run_macos_step() {
  local step_name="$1"
  local step_status

  macos_step_failed=0
  macos_last_error=""

  set +eE
  set -E
  trap 'log_macos_command_error "$step_name" "$?" "$BASH_COMMAND"' ERR
  "$step_name"
  step_status=$?
  trap - ERR
  set +E
  set -e

  if [[ "$macos_step_failed" -ne 0 || "$step_status" -ne 0 ]]; then
    macos_failed_steps+=("$step_name")
  fi
}

# Best-effort `defaults` write for settings that need extra permissions
# (sandboxed apps like Safari or Messages) or vary across macOS versions.
# A failure is recorded as a skip instead of an error, and the rest of the
# step keeps running.
# Usage: defaults_try "<description>" write <domain> <key> ...
defaults_try() {
  local description="$1"
  shift

  if defaults "$@" 2>/dev/null; then
    return 0
  fi

  macos_skipped_settings+=("$description")
  echo "Skipped: $description (defaults $*)" >&2
}

request_full_disk_access() {
  # Full Disk Access can't be granted programmatically (TCC forbids it by
  # design). The most we can do is open the right Settings pane. macOS also
  # requires restarting the terminal app after granting, so sandboxed-app
  # settings apply on the next run.
  has_full_disk_access && return 0

  echo "Warning: this terminal lacks Full Disk Access; sandboxed app settings (Safari, Messages) will be skipped." >&2
  echo "Grant it in the Settings pane that just opened, restart your terminal, and re-run this script." >&2
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true
  return 1
}

summarize_macos_errors() {
  if [[ "${#macos_skipped_settings[@]}" -gt 0 ]]; then
    echo "Skipped ${#macos_skipped_settings[@]} best-effort setting(s): ${macos_skipped_settings[*]}" >&2
  fi

  if [[ "$macos_error_count" -eq 0 ]]; then
    return
  fi

  echo "Warning: macOS setup completed with $macos_error_count logged error(s)." >&2
  echo "Failed macOS setup steps: ${macos_failed_steps[*]}" >&2
  if [[ -n "$macos_error_log" ]]; then
    echo "Review the macOS setup log: $macos_error_log" >&2
  fi
}

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

  sudo_askpass /usr/sbin/scutil --set "$key" "$value"
}

configure_hostname() {
  local hostname="${DOTFILES_HARDWARE_HOSTNAME:-}"

  [[ -n "$hostname" ]] || return

  if [[ ! "$hostname" =~ ^[A-Za-z0-9-]+$ ]]; then
    echo "Error: invalid hardware hostname: $hostname" >&2
    return 1
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

  defaults write com.apple.HIToolbox AppleFnUsageType -int 0

  defaults write kCFPreferencesAnyApplication TSMLanguageIndicatorEnabled -bool false
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

  defaults write com.apple.finder _FXEnableColumnAutoSizing -bool true

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

  defaults write com.apple.dock "expose-group-apps" -bool true

  # Show 24 hours clock instead of 12-hour format
  # Ventura+ follows the Language & Region setting; Show24Hour is the
  # pre-Ventura key, kept for older machines
  defaults write NSGlobalDomain AppleICUForce24HourTime -bool true
  defaults write com.apple.menuextra.clock Show24Hour -int 1

  # Don't show siri in menubar to save space
  defaults write com.apple.Siri StatusMenuVisible -int 0

  # Don't show spotlight in menubar
  # Using Raycast instead as a more powerful alternative
  defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1

  # Show battery percentage in menubar
  # Write through cfprefsd instead of the ByHost plist path so the change
  # isn't overwritten from the daemon's cache
  defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
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
  sudo_askpass /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off --setallowsigned off --setallowsignedapp off --setstealthmode on --setglobalstate on
}

configure_filevault() {
  ###############################################################################
  # FileVault Disk Encryption                                                   #
  ###############################################################################

  # Enable FileVault if not already enabled
  # Improves security by encrypting the entire disk
  if fdesetup status | grep -q "FileVault is On"; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "Skipping FileVault enablement: needs an interactive terminal to prompt for the login password" >&2
    return 0
  fi

  # fdesetup prints the recovery key to stdout exactly once; save a copy so
  # it doesn't get lost in the scrollback
  local key_file="$HOME/Desktop/FileVault Recovery Key.txt"

  echo "Enabling FileVault; the recovery key will also be saved to: $key_file" >&2
  if (umask 177 && sudo_askpass fdesetup enable -user "$(whoami)" | tee "$key_file"); then
    echo "IMPORTANT: store the FileVault recovery key in your password manager, then delete '$key_file'." >&2
  else
    rm -f "$key_file"
    echo "Warning: FileVault enablement failed" >&2
    return 1
  fi
}

configure_power_management() {
  ###############################################################################
  # Power Management                                                            #
  ###############################################################################

  # Wake the machine when the laptop lid is opened
  sudo_askpass pmset -a lidwake 1

  # Power management settings for when plugged in (AC power)
  # Disable machine sleep while charging for desktop replacement mode
  sudo_askpass pmset -c sleep 0
  sudo_askpass pmset -c displaysleep 30

  # Power management settings for battery power (laptops only; -b fails on
  # Macs without a battery)
  # Set display sleep to happen before system sleep
  if pmset -g batt 2>/dev/null | grep -q "InternalBattery"; then
    sudo_askpass pmset -b displaysleep 10
    sudo_askpass pmset -b sleep 15
  fi
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

  # Show developer-focused crash reporter dialogs
  defaults write com.apple.CrashReporter DialogType -string "developer"

  # Prevent Time Machine from prompting to use new hard drives as backup volume
  defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

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
  sudo_askpass /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate
}

restart_affected_services() {
  ###############################################################################
  # Apply Changes & Restart Services                                            #
  ###############################################################################

  # Restart affected services to apply changes immediately; killall exits
  # non-zero when a process isn't running (headless or SSH sessions), which
  # isn't an error here
  local app
  for app in SystemUIServer Dock Finder; do
    killall "$app" 2>/dev/null || true
  done
}

setup_macos_error_log
run_macos_step close_system_settings
run_macos_step configure_hostname
run_macos_step configure_keyboard_input
run_macos_step configure_screen_display
run_macos_step configure_finder_files
run_macos_step configure_dock_menu_bar
run_macos_step configure_updates_security
run_macos_step configure_filevault
run_macos_step configure_power_management
run_macos_step configure_application_settings
run_macos_step configure_keyboard_shortcuts
run_macos_step configure_remote_access
run_macos_step restart_affected_services
summarize_macos_errors
