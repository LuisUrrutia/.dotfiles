#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

macos_error_count=0
macos_step_failed=0
macos_install_log="${DOTFILES_MACOS_INSTALL_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/macos-install.log}"
macos_failed_steps=()
macos_skipped_settings=()
macos_needs_full_disk_access=false
macos_log_pipe_dir=""
macos_log_tee_pids=()

# Bash re-fires ERR for every enclosing function that returns a failed status
# as its own last command, and does not refresh BASH_COMMAND for those fires,
# so they replay whatever conditional the handler ran last. Closing the handler
# with this marker makes the replays identifiable. It has to be a conditional:
# bash restores BASH_COMMAND after a simple command like `:`, so a simple
# command leaves the real failure in place and the replay looks genuine.
macos_trap_marker='[[ macos_error_trap == macos_error_trap ]]'

setup_macos_log() {
  local log_dir

  log_dir="$(dirname "$macos_install_log")"
  if ! mkdir -p "$log_dir" || ! : >>"$macos_install_log"; then
    echo "Warning: unable to write the macOS setup log at $macos_install_log" >&2
    macos_install_log=""
    return 0
  fi

  printf '\n[%s] Starting macOS setup\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$macos_install_log"

  # Named pipes rather than process substitution: bash 3.2 is the only bash on
  # a stock macOS and does not publish a process substitution's PID, so there
  # would be no way to drain the writers before the script exits. Two writers
  # means stdout and stderr can interleave in the file; order within stderr,
  # where the warnings and the failing commands' own output land, is total.
  macos_log_pipe_dir="$(mktemp -d)"
  mkfifo "$macos_log_pipe_dir/stdout" "$macos_log_pipe_dir/stderr"
  exec 3>&1 4>&2
  tee -a "$macos_install_log" <"$macos_log_pipe_dir/stdout" >&3 &
  macos_log_tee_pids+=("$!")
  tee -a "$macos_install_log" <"$macos_log_pipe_dir/stderr" >&4 &
  macos_log_tee_pids+=("$!")
  exec 1>"$macos_log_pipe_dir/stdout" 2>"$macos_log_pipe_dir/stderr"
  trap close_macos_log EXIT

  echo "Logging macOS setup output to $macos_install_log" >&2
}

close_macos_log() {
  [[ -n "$macos_log_pipe_dir" ]] || return 0

  exec 1>&3 2>&4
  exec 3>&- 4>&-
  wait "${macos_log_tee_pids[@]}" 2>/dev/null || true
  rm -rf "$macos_log_pipe_dir"
  macos_log_pipe_dir=""
}

log_macos_command_error() {
  local step_name="$1"
  local status="$2"
  local command="$3"
  local frames=""
  local index

  # See macos_trap_marker: a replayed fire reports a failure that was already
  # logged deeper in the call stack, under a command name that is no longer
  # the one that failed.
  [[ "$command" == "$macos_trap_marker" ]] && return 0

  # sudo_askpass and friends end in a bare `return`, so the command alone does
  # not identify the failure; the call chain does. A line number would not:
  # bash 3.2 reports a function's definition line here, not the failing one.
  for ((index = 1; index < ${#FUNCNAME[@]}; index++)); do
    [[ "${FUNCNAME[index]}" == run_macos_step ]] && break
    frames="${frames:+$frames<-}${FUNCNAME[index]}"
  done

  macos_step_failed=1
  macos_error_count=$((macos_error_count + 1))
  printf "Warning: macOS setup step '%s' failed with exit %s in %s: %s\n" \
    "$step_name" "$status" "${frames:-$step_name}" "${command//$'\n'/ }" >&2
}

run_macos_step() {
  local step_name="$1"
  local step_status

  macos_step_failed=0

  set +eE
  set -E
  # The trailing conditional is macos_trap_marker; keep the two literals equal.
  trap 'log_macos_command_error "$step_name" "$?" "$BASH_COMMAND"; [[ macos_error_trap == macos_error_trap ]]' ERR
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
  local error_output

  if error_output="$(defaults "$@" 2>&1)"; then
    return 0
  fi

  macos_skipped_settings+=("$description")
  # What `defaults` printed is the only thing separating a missing permission
  # from a malformed invocation here. Dropping it made a typo in these flags
  # read exactly like a TCC denial, so a real bug in this file would be
  # filed away as an expected skip.
  echo "Skipped: $description (defaults $*): ${error_output//$'\n'/ }" >&2
}

# Full Disk Access can't be granted programmatically (TCC forbids it by
# design), so the most this script can do is warn and point at the pane. The
# warning goes first, to explain the skips that follow, but the pane only
# opens once every step has run: close_system_settings quits System Settings
# on the very next line, and a Settings window left open for the rest of the
# run can overwrite what the steps below write.
warn_missing_full_disk_access() {
  has_full_disk_access && return 0

  macos_needs_full_disk_access=true
  echo "Warning: this terminal lacks Full Disk Access; sandboxed app settings (Safari, Messages) will be skipped." >&2
  echo "The Settings pane to grant it opens at the end of this run." >&2
}

open_full_disk_access_pane() {
  [[ "$macos_needs_full_disk_access" == true ]] || return 0

  # macOS also requires restarting the terminal app after granting, so
  # sandboxed-app settings only apply on the next run
  echo "Grant Full Disk Access in the Settings pane that just opened, restart your terminal, and re-run this script." >&2
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true
}

summarize_macos_errors() {
  if [[ "${#macos_skipped_settings[@]}" -gt 0 ]]; then
    echo "Skipped ${#macos_skipped_settings[@]} best-effort setting(s): ${macos_skipped_settings[*]}" >&2
  fi

  if [[ "$macos_error_count" -eq 0 ]]; then
    return
  fi

  echo "Warning: macOS setup completed with $macos_error_count logged error(s)." >&2
  # bash 3.2 treats an empty array as unset under `set -u`, so expanding it
  # unguarded would abort the summary instead of printing it
  if [[ "${#macos_failed_steps[@]}" -gt 0 ]]; then
    echo "Failed macOS setup steps: ${macos_failed_steps[*]}" >&2
  fi
  if [[ -n "$macos_install_log" ]]; then
    echo "Review the macOS setup log: $macos_install_log" >&2
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

  [[ -n "$hostname" ]] || return 0

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

configure_screen_lock() {
  ###############################################################################
  # Screen Lock                                                                 #
  ###############################################################################

  # Require the password immediately once the screen saver or display sleep
  # starts. Sonoma stopped consulting com.apple.screensaver's askForPassword
  # and askForPasswordDelay, so writing them looked like it worked while the
  # machine kept whatever delay it already had. sysadminctl is the supported
  # path, and it wants the account password rather than sudo rights.
  local delay

  delay="$(sysadminctl -screenLock status 2>&1 |
    sed -n 's/.*screenLock delay is \([0-9]*\) seconds.*/\1/p')"
  if [[ "$delay" == "0" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "Skipping screen lock delay: sysadminctl needs an interactive terminal to prompt for the account password" >&2
    return 0
  fi

  echo "Setting the screen lock delay to immediate; sysadminctl will ask for your account password." >&2
  sysadminctl -screenLock immediate -password -
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
}

configure_dock_menu_bar() {
  ###############################################################################
  # Dock & Menu Bar                                                             #
  ###############################################################################

  # Size of dock icons (in pixels)
  defaults write com.apple.dock tilesize -int 55

  # Auto hide dock to maximize screen real estate
  defaults write com.apple.dock autohide -bool true

  defaults write com.apple.dock "expose-group-apps" -bool true

  # Show 24 hours clock instead of 12-hour format. This is the system-wide
  # override the Language & Region pane writes; the menu bar clock follows it.
  defaults write NSGlobalDomain AppleICUForce24HourTime -bool true

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

  # Enable automatic software update checks. softwareupdated reads these from
  # the system domain, so they go there with sudo; the same keys in the
  # per-user domain are inert. AutomaticCheckEnabled and ScheduleFrequency do
  # not exist in the system domain at all, and this CLI covers the check.
  softwareupdate --schedule on

  # Download newly available updates in background
  sudo_askpass defaults write /Library/Preferences/com.apple.SoftwareUpdate \
    AutomaticDownload -bool true

  # Install System data files & security updates automatically
  # Critical for maintaining system security
  sudo_askpass defaults write /Library/Preferences/com.apple.SoftwareUpdate \
    ConfigDataInstall -bool true
  sudo_askpass defaults write /Library/Preferences/com.apple.SoftwareUpdate \
    CriticalUpdateInstall -bool true

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

  # Use plain text by default in TextEdit
  defaults write com.apple.TextEdit RichText -int 0

  # Use UTF-8 for TextEdit open and save operations
  defaults write com.apple.TextEdit PlainTextEncoding -int 4
  defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

  # Show developer-focused crash reporter dialogs
  defaults write com.apple.CrashReporter DialogType -string "developer"

  # Prevent Time Machine from prompting to use new hard drives as backup volume
  defaults_try "Time Machine new-disk prompt" \
    write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

  # Mail is sandboxed, so this needs Full Disk Access; without it it is
  # recorded as a skip rather than failing the whole step
  defaults_try "Mail inline attachment previews" \
    write com.apple.mail DisableInlineAttachmentViewing -bool true

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

# Emits every localized title Messages can show for its delete-conversation
# menu items, one per line. Read from ChatKit rather than hardcoded so a new
# Apple locale or a reworded menu item keeps working without a dotfiles edit.
messages_delete_titles() {
  local loctable="${DOTFILES_CHATKIT_LOCTABLE:-/System/iOSSupport/System/Library/PrivateFrameworks/ChatKit.framework/Versions/A/Resources/ChatKit.loctable}"

  [[ -r "$loctable" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  # LocProvenance sits alongside the language dictionaries and is not one, so
  # the object filter has to come before the key lookups
  plutil -convert json -o - "$loctable" 2>/dev/null | jq -r '
    [ .[]
      | select(type == "object")
      | (.DELETE_CONVERSATION_ELLIPSIS, .DELETE_CONVERSATIONS_ELLIPSIS) ]
    | map(select(type == "string"))
    | unique
    | .[]
  ' 2>/dev/null
}

configure_messages_shortcuts() {
  ###############################################################################
  # Messages                                                                    #
  ###############################################################################

  # Conversation > Delete Conversation ships without a shortcut, and
  # NSUserKeyEquivalents matches menu items by the title the user sees, so the
  # binding has to cover every language macOS might run in. Both the singular
  # and plural titles are bound: Messages swaps to the plural as soon as more
  # than one conversation is selected, and a missing entry drops the shortcut
  # exactly when deleting in bulk.
  # NSBackspaceCharacter (0x08) is the character AppKit draws as the erase-left
  # glyph, so this reads as Command-Delete, matching Finder's Move to Trash.
  local shortcut=$'@\b'
  local title
  local -a pairs=()

  while IFS= read -r title; do
    if [[ -n "$title" ]]; then
      pairs+=("$title" "$shortcut")
    fi
  done < <(messages_delete_titles)

  # ChatKit is a private framework and can move between macOS releases. An
  # empty -dict-add would take the key with it, so fall back to the languages
  # this machine actually runs in instead of writing nothing.
  if [[ "${#pairs[@]}" -eq 0 ]]; then
    pairs=(
      "Delete Conversation…" "$shortcut"
      "Delete Conversations…" "$shortcut"
      "Eliminar conversación…" "$shortcut"
      "Eliminar conversaciones…" "$shortcut"
    )
  fi

  # Messages is sandboxed, so this needs Full Disk Access; without it it is
  # recorded as a skip rather than failing the whole step. -dict-add merges,
  # leaving any shortcut added from System Settings in place.
  defaults_try "Messages delete-conversation shortcut" \
    write com.apple.MobileSMS NSUserKeyEquivalents -dict-add "${pairs[@]}"
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
  # ControlCenter owns the menu bar on Ventura and later, so the Siri,
  # Spotlight and battery-percentage settings above need it restarted too
  local app
  for app in ControlCenter SystemUIServer Dock Finder; do
    killall "$app" 2>/dev/null || true
  done

  # Symbolic hotkeys are read at login and none of the processes above reloads
  # them, so a shortcut disabled in configure_keyboard_shortcuts stays live
  # until the next login. activateSettings is what System Settings itself uses
  # to apply them in place. Best effort for the same reason as the killalls:
  # failing here only defers the change to the next login.
  local activate_settings="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
  if [[ -x "$activate_settings" ]]; then
    "$activate_settings" -u 2>/dev/null || true
  fi
}

main() {
  setup_macos_log
  # Reports the missing permission up front so the skips below read as
  # expected; the pane to grant it opens after the last step
  warn_missing_full_disk_access
  run_macos_step close_system_settings
  run_macos_step configure_hostname
  run_macos_step configure_keyboard_input
  run_macos_step configure_screen_display
  run_macos_step configure_screen_lock
  run_macos_step configure_finder_files
  run_macos_step configure_dock_menu_bar
  run_macos_step configure_updates_security
  run_macos_step configure_filevault
  run_macos_step configure_power_management
  run_macos_step configure_application_settings
  run_macos_step configure_keyboard_shortcuts
  run_macos_step configure_messages_shortcuts
  run_macos_step configure_remote_access
  run_macos_step restart_affected_services
  summarize_macos_errors
  open_full_disk_access_pane
  close_macos_log
}

if [[ "${DOTFILES_MACOS_NO_MAIN:-false}" != true ]]; then
  main "$@"
fi
