#!/usr/bin/env bash

# Temporary connectivity rescue for fresh macOS bootstrap runs. The root
# Bootstrapper owns orchestration; this file owns the RiseupVPN adapter.

NETWORK_RESCUE_RISEUP_ROOT="/Applications/RiseupVPN"
NETWORK_RESCUE_RISEUP_APP="$NETWORK_RESCUE_RISEUP_ROOT/RiseupVPN.app"
NETWORK_RESCUE_RISEUP_POST_INSTALL="$NETWORK_RESCUE_RISEUP_ROOT/post-install"
NETWORK_RESCUE_RISEUP_DOWNLOAD_URL="https://downloads.leap.se/RiseupVPN/osx/beta/RiseupVPN-installer-0.25.8-aarch64.dmg"
NETWORK_RESCUE_RISEUP_SHA256="4e6fb5d66efaab819821483235c7d3141ceca7dbba9b2d39b8b70f4963bd8b98"
NETWORK_RESCUE_RISEUP_BUNDLE_ID="se.leap.riseup-vpn"
NETWORK_RESCUE_LEGACY_RISEUP_BUNDLE_ID="se.leap.bitmask"
NETWORK_RESCUE_MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/network-rescue-riseupvpn"
LEGACY_NETWORK_RESCUE_WARP_APP="/Applications/Cloudflare WARP.app"
LEGACY_NETWORK_RESCUE_WARP_MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/network-rescue-warp"
NETWORK_RESCUE_TEMP_DIR=""
NETWORK_RESCUE_MOUNT_DIR=""
GITHUB_API_RATE_LIMIT_URL="https://api.github.com/rate_limit"

github_web_connectivity_available() {
  /usr/bin/curl --head --location --silent --show-error \
    --connect-timeout 8 --max-time 20 \
    https://github.com/ >/dev/null 2>&1
}

github_git_connectivity_available() {
  GIT_TERMINAL_PROMPT=0 /usr/bin/git ls-remote \
    https://github.com/Homebrew/brew.git HEAD >/dev/null 2>&1
}

github_release_connectivity_available() {
  # The root returns an HTTP error, but curl still proves DNS, TLS, and routing
  # to the host that serves GitHub release downloads.
  /usr/bin/curl --head --silent --show-error \
    --connect-timeout 8 --max-time 20 \
    https://release-assets.githubusercontent.com/ >/dev/null 2>&1
}

github_connectivity_available() {
  local web_pid=""
  local git_pid=""
  local release_pid=""
  local status=0

  github_web_connectivity_available &
  web_pid="$!"
  github_git_connectivity_available &
  git_pid="$!"
  github_release_connectivity_available &
  release_pid="$!"

  wait "$web_pid" || status=1
  wait "$git_pid" || status=1
  wait "$release_pid" || status=1
  return "$status"
}

github_api_rate_limit_response() {
  local token=""

  if [[ -n "${MISE_GITHUB_TOKEN:-}" ]]; then
    token="$MISE_GITHUB_TOKEN"
  elif [[ -n "${GITHUB_API_TOKEN:-}" ]]; then
    token="$GITHUB_API_TOKEN"
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    token="$GITHUB_TOKEN"
  fi

  if command -v gh >/dev/null 2>&1; then
    if [[ -n "$token" ]]; then
      GH_TOKEN="$token" gh api rate_limit
      return
    fi
    if gh auth status --hostname github.com >/dev/null 2>&1; then
      gh api rate_limit
      return
    fi
  fi

  /usr/bin/curl --fail --silent --show-error \
    --connect-timeout 8 --max-time 20 \
    --header 'Accept: application/vnd.github+json' \
    --header 'X-GitHub-Api-Version: 2022-11-28' \
    "$GITHUB_API_RATE_LIMIT_URL"
}

github_api_rate_limit_value() {
  local response="$1"
  local field="$2"

  printf '%s' "$response" |
    /usr/bin/plutil -extract "resources.core.$field" raw - 2>/dev/null
}

github_api_rate_limit_exhausted() {
  local response=""
  local remaining=""

  if ! response="$(github_api_rate_limit_response)"; then
    say "Warning: could not check whether GitHub API exhaustion caused the install failure." >&2
    return 1
  fi
  remaining="$(github_api_rate_limit_value "$response" remaining || true)"
  if [[ ! "$remaining" =~ ^[0-9]+$ ]]; then
    say "Warning: GitHub returned an unreadable API rate-limit response after the install failure." >&2
    return 1
  fi
  [[ "$remaining" -eq 0 ]]
}

mise_github_backend_count() {
  local backend="$1"
  local mise_config="$DOTFILES/tools/mise/config/.config/mise/config.toml"
  local count=0

  if [[ -f "$mise_config" ]]; then
    count="$(
      /usr/bin/grep -Ec "^\"${backend}:" "$mise_config" || true
    )"
  fi
  printf '%s\n' "$count"
}

tmux_github_git_source_count() {
  local tmux_config="$DOTFILES/tools/tmux/config/.tmux.conf"

  if [[ ! -f "$tmux_config" ]]; then
    printf '0\n'
    return
  fi
  /usr/bin/sed -n \
    "s|.*@plugin[[:space:]]*'https://github.com/\([^']*\)'.*|\1|p" \
    "$tmux_config" | /usr/bin/sort -u | /usr/bin/wc -l | /usr/bin/tr -d ' '
}

vim_github_git_source_count() {
  local plugins_dir="$DOTFILES/tools/vim/config/.config/nvim/lua/plugins"
  local lazy_config="$DOTFILES/tools/vim/config/.config/nvim/lua/config/lazy.lua"
  local plugin_count=0
  local lazy_count=0

  if [[ -d "$plugins_dir" ]]; then
    plugin_count="$(
      {
        /usr/bin/grep -Eho \
          "['\"][A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+['\"]" \
          "$plugins_dir"/*.lua 2>/dev/null || true
      } | /usr/bin/sed -E "s/['\"]//g" | /usr/bin/sort -u |
        /usr/bin/wc -l | /usr/bin/tr -d ' '
    )"
  fi
  if [[ -f "$lazy_config" ]] &&
    /usr/bin/grep -F 'https://github.com/folke/lazy.nvim.git' \
      "$lazy_config" >/dev/null; then
    lazy_count=1
  fi
  printf '%s\n' "$((plugin_count + lazy_count))"
}

vim_treesitter_parser_source_count() {
  local treesitter_config="$DOTFILES/tools/vim/config/.config/nvim/lua/config/treesitter.lua"

  if [[ ! -f "$treesitter_config" ]]; then
    printf '0\n'
    return
  fi
  /usr/bin/awk '
    /^M\.parsers = \{/ { in_parsers = 1; next }
    in_parsers && /^}/ { print count + 0; exit }
    in_parsers && /^[[:space:]]*'\''[A-Za-z0-9_-]+'\''[,]?[[:space:]]*$/ { count++ }
  ' "$treesitter_config"
}

github_epoch_now() {
  /bin/date '+%s'
}

github_rate_limit_sleep() {
  /bin/sleep "$1"
}

wait_for_github_api_reset() {
  local phase="$1"
  local reset="$2"
  local reset_display="$3"
  local now=""
  local deadline=""
  local wait_seconds=""
  local sleep_seconds=""

  deadline=$((reset + 5))
  say "Waiting until its reset at $reset_display (epoch $reset) before $phase. Press Ctrl-C to stop."
  while :; do
    now="$(github_epoch_now)"
    if [[ ! "$now" =~ ^[0-9]+$ ]]; then
      say "Error: could not determine the current time while waiting for GitHub." >&2
      return 1
    fi

    wait_seconds=$((deadline - now))
    if [[ "$wait_seconds" -le 0 ]]; then
      return 0
    fi
    sleep_seconds="$wait_seconds"
    if [[ "$sleep_seconds" -gt 60 ]]; then
      sleep_seconds=60
    fi
    if ! github_rate_limit_sleep "$sleep_seconds"; then
      say "Error: GitHub rate-limit wait was interrupted before $phase." >&2
      return 1
    fi
  done
}

github_api_budget_available() {
  local phase="$1"
  local required="$2"
  local response=""
  local remaining=""
  local limit=""
  local reset=""
  local reset_display=""

  while :; do
    if ! response="$(github_api_rate_limit_response)"; then
      say "Error: could not read GitHub API rate limits through RiseupVPN." >&2
      return 1
    fi

    remaining="$(github_api_rate_limit_value "$response" remaining || true)"
    limit="$(github_api_rate_limit_value "$response" limit || true)"
    reset="$(github_api_rate_limit_value "$response" reset || true)"
    if [[ ! "$remaining" =~ ^[0-9]+$ || ! "$limit" =~ ^[0-9]+$ ||
      ! "$reset" =~ ^[0-9]+$ || ! "$required" =~ ^[0-9]+$ ]]; then
      say "Error: GitHub returned an unreadable API rate-limit response." >&2
      return 1
    fi

    if [[ "$remaining" -ge "$required" ]]; then
      say "GitHub API through RiseupVPN: $remaining/$limit remaining; $phase needs $required core API requests."
      return 0
    fi

    reset_display="$(/bin/date -r "$reset" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || printf 'unknown')"
    if [[ "$limit" -lt "$required" ]]; then
      say "Error: GitHub API rate limit through RiseupVPN is $remaining/$limit; $phase needs $required core API requests." >&2
      say "Authenticated GitHub access is required for this phase; the anonymous limit cannot satisfy it." >&2
      say "Rate limit resets at $reset_display (epoch $reset), but waiting cannot raise this session's $limit-request limit." >&2
      return 1
    fi

    say "GitHub API through RiseupVPN is $remaining/$limit; $phase needs $required core API requests."
    if ! wait_for_github_api_reset "$phase" "$reset" "$reset_display"; then
      return 1
    fi
  done
}

github_phase_preflight() {
  local phase="$1"
  local required="$2"
  local traffic_summary="$3"

  section "GitHub preflight: $phase"
  if ! riseupvpn_is_active; then
    if ! is_interactive; then
      say "Error: RiseupVPN disconnected before $phase." >&2
      return 1
    fi
    note "RiseupVPN disconnected before $phase; reconnecting it now."
    activate_riseupvpn_rescue
  fi
  if ! github_connectivity_available; then
    say "Error: GitHub routes are not reliable enough to start $phase." >&2
    return 1
  fi
  say "$traffic_summary"
  github_api_budget_available "$phase" "$required"
}

riseupvpn_app_installed() {
  [[ -d "$NETWORK_RESCUE_RISEUP_APP" ]]
}

riseupvpn_rescue_is_managed() {
  [[ -f "$NETWORK_RESCUE_MARKER" ]]
}

riseupvpn_is_active() {
  /usr/bin/pgrep -f "$NETWORK_RESCUE_RISEUP_APP/openvpn.leap" >/dev/null 2>&1
}

download_riseupvpn_image() {
  local destination="$1"

  /usr/bin/curl --fail --location --show-error \
    --connect-timeout 10 --max-time 1200 \
    --retry 5 --retry-delay 2 --retry-all-errors \
    --output "$destination" "$NETWORK_RESCUE_RISEUP_DOWNLOAD_URL"
}

riseupvpn_image_is_valid() {
  /usr/bin/hdiutil verify "$1" >/dev/null
}

riseupvpn_image_sha256() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{ print $1 }'
}

riseupvpn_image_is_expected() {
  local checksum=""

  riseupvpn_image_is_valid "$1" || return 1
  if ! checksum="$(riseupvpn_image_sha256 "$1")"; then
    return 1
  fi
  [[ "$checksum" == "$NETWORK_RESCUE_RISEUP_SHA256" ]]
}

mount_riseupvpn_image() {
  /usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$2" "$1" >/dev/null
}

unmount_riseupvpn_image() {
  /usr/bin/hdiutil detach "$1" >/dev/null
}

find_riseupvpn_payload_container() {
  local mount_dir="$1"
  local installer=""
  local installers=()

  while IFS= read -r installer; do
    installers+=("$installer")
  done < <(/usr/bin/find "$mount_dir" -maxdepth 1 -type d \
    -name 'RiseupVPN-installer-*.app' -print)

  [[ "${#installers[@]}" -eq 1 ]] || return 1
  printf '%s\n' "${installers[0]}"
}

riseupvpn_archive_offsets() {
  LC_ALL=C /usr/bin/grep -aob $'7z\xbc\xaf\x27\x1c' "$1" |
    LC_ALL=C /usr/bin/sed 's/:.*//'
}

riseupvpn_archive_paths_are_safe() {
  local archive="$1"
  local entry=""

  /usr/bin/bsdtar -tf "$archive" >/dev/null || return 1
  while IFS= read -r entry; do
    case "$entry" in
    /* | ../* | */../* | */..)
      return 1
      ;;
    esac
  done < <(/usr/bin/bsdtar -tf "$archive")
}

extract_riseupvpn_payload() {
  local container="$1"
  local payload_dir="$2"
  local metadata_dir="$3"
  local data_file="$container/Contents/Resources/installer.dat"
  local payload_archive="$NETWORK_RESCUE_TEMP_DIR/payload.7z"
  local metadata_archive="$NETWORK_RESCUE_TEMP_DIR/metadata.7z"
  local offset=""
  local offsets=()

  [[ -f "$data_file" ]] || return 1
  while IFS= read -r offset; do
    [[ "$offset" =~ ^[0-9]+$ ]] || return 1
    offsets+=("$offset")
  done < <(riseupvpn_archive_offsets "$data_file")
  [[ "${#offsets[@]}" -eq 2 ]] || return 1

  /usr/bin/tail -c "+$((offsets[0] + 1))" "$data_file" >"$payload_archive"
  /usr/bin/tail -c "+$((offsets[1] + 1))" "$data_file" >"$metadata_archive"
  riseupvpn_archive_paths_are_safe "$payload_archive" || return 1
  riseupvpn_archive_paths_are_safe "$metadata_archive" || return 1

  /bin/mkdir -p "$payload_dir" "$metadata_dir"
  /usr/bin/bsdtar -xf "$payload_archive" -C "$payload_dir"
  /usr/bin/bsdtar -xf "$metadata_archive" -C "$metadata_dir"
}

riseupvpn_bundle_identifier() {
  local app="${1:-$NETWORK_RESCUE_RISEUP_APP}"

  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
    "$app/Contents/Info.plist" 2>/dev/null
}

riseupvpn_bundle_executable() {
  local app="${1:-$NETWORK_RESCUE_RISEUP_APP}"

  /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
    "$app/Contents/Info.plist" 2>/dev/null
}

riseupvpn_binary_architectures() {
  /usr/bin/lipo -archs "$1" 2>/dev/null
}

riseupvpn_binary_supports_arm64() {
  local architectures=""

  if ! architectures="$(riseupvpn_binary_architectures "$1")"; then
    return 1
  fi
  [[ " $architectures " == *' arm64 '* ]]
}

riseupvpn_app_payload_is_expected() {
  local app="$1"
  local bundle_identifier=""
  local bundle_executable=""

  [[ -d "$app" ]] || return 1
  if ! bundle_identifier="$(riseupvpn_bundle_identifier "$app")"; then
    return 1
  fi
  if ! bundle_executable="$(riseupvpn_bundle_executable "$app")"; then
    return 1
  fi
  [[ "$bundle_identifier" == "$NETWORK_RESCUE_RISEUP_BUNDLE_ID" ]] || return 1
  [[ -n "$bundle_executable" ]] || return 1
  riseupvpn_binary_supports_arm64 "$app/Contents/MacOS/$bundle_executable" &&
    riseupvpn_binary_supports_arm64 "$app/bitmask-helper" &&
    riseupvpn_binary_supports_arm64 "$app/openvpn.leap"
}

riseupvpn_native_payload_is_expected() {
  riseupvpn_app_payload_is_expected "$1" &&
    [[ -x "$2" ]] &&
    riseupvpn_binary_supports_arm64 "$2"
}

riseupvpn_app_layout_is_expected() {
  riseupvpn_app_payload_is_expected "$NETWORK_RESCUE_RISEUP_APP"
}

run_riseupvpn_post_install() {
  sudo_askpass "$NETWORK_RESCUE_RISEUP_POST_INSTALL" \
    -action post-install -appname RiseupVPN \
    -socket-uid "$(/usr/bin/id -u)" -socket-gid "$(/usr/bin/id -g)"
}

run_riseupvpn_post_uninstall() {
  sudo_askpass "$NETWORK_RESCUE_RISEUP_POST_INSTALL" \
    -action uninstall -stage uninstall -appname RiseupVPN
}

copy_riseupvpn_native_payload() {
  local source_app="$1"
  local source_post_install="$2"

  sudo_askpass /bin/mkdir -p "$NETWORK_RESCUE_RISEUP_ROOT"
  sudo_askpass /usr/bin/ditto "$source_app" "$NETWORK_RESCUE_RISEUP_APP"
  sudo_askpass /usr/bin/install -m 0755 \
    "$source_post_install" "$NETWORK_RESCUE_RISEUP_POST_INSTALL"
}

mark_riseupvpn_rescue_managed() {
  /bin/mkdir -p "$(dirname "$NETWORK_RESCUE_MARKER")"
  /usr/bin/touch "$NETWORK_RESCUE_MARKER"
}

install_riseupvpn_rescue() {
  local image=""
  local container=""
  local payload_dir=""
  local metadata_dir=""
  local source_app=""
  local source_post_install=""

  NETWORK_RESCUE_TEMP_DIR="$(/usr/bin/mktemp -d)"
  NETWORK_RESCUE_MOUNT_DIR="$NETWORK_RESCUE_TEMP_DIR/mount"
  payload_dir="$NETWORK_RESCUE_TEMP_DIR/payload"
  metadata_dir="$NETWORK_RESCUE_TEMP_DIR/metadata"
  image="$NETWORK_RESCUE_TEMP_DIR/RiseupVPN.dmg"
  /bin/mkdir -p "$NETWORK_RESCUE_MOUNT_DIR"
  at_exit "
if /sbin/mount | /usr/bin/grep -F ' on ${NETWORK_RESCUE_MOUNT_DIR} (' >/dev/null 2>&1; then
  /usr/bin/hdiutil detach '${NETWORK_RESCUE_MOUNT_DIR}' >/dev/null 2>&1 || true
fi
/bin/rm -rf '${NETWORK_RESCUE_TEMP_DIR}'
  "

  say "Downloading the official RiseupVPN rescue image..."
  download_riseupvpn_image "$image"

  if ! riseupvpn_image_is_expected "$image"; then
    say "Error: the RiseupVPN ARM disk image failed its integrity or pinned checksum verification." >&2
    return 1
  fi

  mount_riseupvpn_image "$image" "$NETWORK_RESCUE_MOUNT_DIR"
  if ! container="$(find_riseupvpn_payload_container "$NETWORK_RESCUE_MOUNT_DIR")"; then
    say "Error: the RiseupVPN disk image does not contain exactly one expected payload container." >&2
    return 1
  fi
  if ! extract_riseupvpn_payload "$container" "$payload_dir" "$metadata_dir"; then
    say "Error: the pinned RiseupVPN ARM payload could not be extracted safely." >&2
    return 1
  fi
  source_app="$payload_dir/RiseupVPN.app"
  source_post_install="$metadata_dir/post-install"
  if ! riseupvpn_native_payload_is_expected "$source_app" "$source_post_install"; then
    say "Error: the RiseupVPN payload is not the expected native ARM application." >&2
    return 1
  fi

  say "Installing the native ARM RiseupVPN connectivity rescue without Rosetta..."
  prepare_riseupvpn_install_target
  mark_riseupvpn_rescue_managed
  copy_riseupvpn_native_payload "$source_app" "$source_post_install"
  run_riseupvpn_post_install
  unmount_riseupvpn_image "$NETWORK_RESCUE_MOUNT_DIR"
  NETWORK_RESCUE_MOUNT_DIR=""

  if ! riseupvpn_app_layout_is_expected; then
    say "Error: installed RiseupVPN application has an unexpected layout." >&2
    return 1
  fi
}

activate_riseupvpn_rescue() {
  local attempt=1

  if riseupvpn_is_active; then
    return 0
  fi

  /usr/bin/open "$NETWORK_RESCUE_RISEUP_APP"
  say "RiseupVPN does not require an account. Connect its tunnel."
  say "Approve its privileged helper if macOS asks."

  while [[ "$attempt" -le 3 ]]; do
    printf '\033[1m? Press Return after RiseupVPN shows Connected.\033[0m '
    IFS= read -r _
    if riseupvpn_is_active; then
      return 0
    fi
    note "RiseupVPN does not report an active tunnel yet. Check the app and try again."
    attempt=$((attempt + 1))
  done

  say "Error: RiseupVPN was not activated." >&2
  return 1
}

legacy_warp_rescue_is_managed() {
  [[ -f "$LEGACY_NETWORK_RESCUE_WARP_MARKER" ]]
}

legacy_warp_app_installed() {
  [[ -d "$LEGACY_NETWORK_RESCUE_WARP_APP" ]]
}

uninstall_legacy_warp_rescue() {
  local resources="$LEGACY_NETWORK_RESCUE_WARP_APP/Contents/Resources"

  if ! legacy_warp_app_installed; then
    /bin/rm -f "$LEGACY_NETWORK_RESCUE_WARP_MARKER"
    return 0
  fi
  if [[ ! -x "$resources/uninstall.sh" ]]; then
    say "Error: the managed legacy WARP uninstall script is unavailable." >&2
    return 1
  fi

  (
    cd "$resources" || exit 1
    sudo_askpass ./uninstall.sh -f
  )
  /bin/rm -f "$LEGACY_NETWORK_RESCUE_WARP_MARKER"
}

migrate_legacy_warp_rescue() {
  legacy_warp_rescue_is_managed || return 0

  note "Removing the temporary WARP rescue left by an earlier Bootstrapper."
  uninstall_legacy_warp_rescue
}

managed_legacy_riseupvpn_rescue_exists() {
  local bundle_identifier=""

  riseupvpn_rescue_is_managed || return 1
  riseupvpn_app_installed || return 1
  bundle_identifier="$(riseupvpn_bundle_identifier || true)"
  [[ "$bundle_identifier" == "$NETWORK_RESCUE_LEGACY_RISEUP_BUNDLE_ID" ]]
}

ensure_bootstrap_connectivity() {
  section "Connectivity rescue"
  say "RiseupVPN protects every networked phase of this install."

  if riseupvpn_app_installed; then
    if managed_legacy_riseupvpn_rescue_exists; then
      if ! is_interactive; then
        say "Error: the managed Intel RiseupVPN rescue must be replaced interactively." >&2
        return 1
      fi
      note "Replacing the managed Intel RiseupVPN rescue with its native ARM build."
      install_riseupvpn_rescue
    elif ! riseupvpn_app_layout_is_expected; then
      if ! riseupvpn_rescue_is_managed; then
        say "Error: the existing RiseupVPN application has an unexpected layout; refusing to open it." >&2
        return 1
      fi
      if ! is_interactive; then
        say "Error: the incomplete managed RiseupVPN rescue must be repaired interactively." >&2
        return 1
      fi
      note "Repairing the incomplete managed RiseupVPN ARM rescue."
      install_riseupvpn_rescue
    elif riseupvpn_rescue_is_managed; then
      if [[ ! -x "$NETWORK_RESCUE_RISEUP_POST_INSTALL" ]] ||
        ! riseupvpn_binary_supports_arm64 "$NETWORK_RESCUE_RISEUP_POST_INSTALL"; then
        say "Error: the managed RiseupVPN ARM helper installer is unavailable." >&2
        return 1
      fi
      run_riseupvpn_post_install
    fi
  else
    if ! is_interactive; then
      say "Error: RiseupVPN must be installed interactively before this install can continue." >&2
      return 1
    fi
    install_riseupvpn_rescue
  fi

  # Keep an older managed rescue available while downloading RiseupVPN, then
  # remove it before activating the replacement tunnel.
  migrate_legacy_warp_rescue

  if ! riseupvpn_is_active && ! is_interactive; then
    say "Error: connect RiseupVPN, then rerun ./install.sh." >&2
    return 1
  fi

  activate_riseupvpn_rescue

  if ! github_connectivity_available; then
    say "Error: GitHub is still not reliably reachable through RiseupVPN." >&2
    return 1
  fi

  say "GitHub connectivity recovered through RiseupVPN."
}

quit_riseupvpn() {
  /usr/bin/osascript -e 'tell application "RiseupVPN" to quit' \
    >/dev/null 2>&1 || true
}

uninstall_legacy_riseupvpn_rescue() {
  local uninstaller="$NETWORK_RESCUE_RISEUP_ROOT/uninstall.app/Contents/MacOS/uninstall"

  if [[ ! -x "$uninstaller" ]]; then
    say "Error: the managed legacy RiseupVPN uninstaller is unavailable." >&2
    return 1
  fi

  quit_riseupvpn
  sudo_askpass "$uninstaller" \
    --accept-messages --confirm-command purge
}

uninstall_native_riseupvpn_rescue() {
  if [[ "$NETWORK_RESCUE_RISEUP_ROOT" != "/Applications/RiseupVPN" ||
    "$NETWORK_RESCUE_RISEUP_APP" != "$NETWORK_RESCUE_RISEUP_ROOT/RiseupVPN.app" ]]; then
    say "Error: refusing to remove an unexpected RiseupVPN path." >&2
    return 1
  fi

  quit_riseupvpn
  if [[ -x "$NETWORK_RESCUE_RISEUP_POST_INSTALL" ]]; then
    if ! riseupvpn_binary_supports_arm64 "$NETWORK_RESCUE_RISEUP_POST_INSTALL"; then
      say "Error: the managed RiseupVPN uninstall hook is not native ARM." >&2
      return 1
    fi
    if riseupvpn_app_installed; then
      run_riseupvpn_post_uninstall
    fi
  fi

  sudo_askpass /bin/rm -rf "$NETWORK_RESCUE_RISEUP_ROOT"
}

uninstall_riseupvpn_rescue() {
  local bundle_identifier=""

  if ! riseupvpn_app_installed && [[ ! -d "$NETWORK_RESCUE_RISEUP_ROOT" ]]; then
    /bin/rm -f "$NETWORK_RESCUE_MARKER"
    return 0
  fi

  if riseupvpn_app_installed; then
    bundle_identifier="$(riseupvpn_bundle_identifier || true)"
    case "$bundle_identifier" in
    "$NETWORK_RESCUE_RISEUP_BUNDLE_ID")
      uninstall_native_riseupvpn_rescue
      ;;
    "$NETWORK_RESCUE_LEGACY_RISEUP_BUNDLE_ID")
      uninstall_legacy_riseupvpn_rescue
      ;;
    *)
      say "Error: refusing to remove an unexpected RiseupVPN application." >&2
      return 1
      ;;
    esac
  else
    uninstall_native_riseupvpn_rescue
  fi

  /bin/rm -f "$NETWORK_RESCUE_MARKER"
}

prepare_riseupvpn_install_target() {
  [[ ! -e "$NETWORK_RESCUE_RISEUP_ROOT" ]] && return 0
  if ! riseupvpn_rescue_is_managed; then
    say "Error: $NETWORK_RESCUE_RISEUP_ROOT already exists and is not managed by this Bootstrapper." >&2
    return 1
  fi
  uninstall_riseupvpn_rescue
}

finish_network_rescue() {
  riseupvpn_rescue_is_managed || return 0

  section "Connectivity rescue cleanup"
  say "Removing the temporary RiseupVPN installation..."
  uninstall_riseupvpn_rescue
}
