#!/usr/bin/env bash

# Temporary connectivity rescue for fresh macOS bootstrap runs. The root
# Bootstrapper owns orchestration; this file owns the Cloudflare WARP adapter.

NETWORK_RESCUE_WARP_APP="/Applications/Cloudflare WARP.app"
NETWORK_RESCUE_WARP_DOWNLOAD_URL="https://downloads.cloudflareclient.com/v1/download/macos/ga"
NETWORK_RESCUE_WARP_TEAM_ID="68WVV388M8"
NETWORK_RESCUE_WARP_BUNDLE_ID="com.cloudflare.1dot1dot1dot1.macos"
NETWORK_RESCUE_MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/network-rescue-warp"
NETWORK_RESCUE_TEMP_DIR=""
GITHUB_API_RATE_LIMIT_URL="https://api.github.com/rate_limit"
GITHUB_API_BUDGET_MARGIN=2

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

github_api_required_budget() {
  local mise_config="$DOTFILES/tools/mise/config/.config/mise/config.toml"
  local github_release_sources=0

  if [[ -f "$mise_config" ]]; then
    github_release_sources="$(
      /usr/bin/grep -Ec '^"(aqua|github):' "$mise_config" || true
    )"
  fi
  printf '%s\n' "$((github_release_sources + GITHUB_API_BUDGET_MARGIN))"
}

github_api_budget_available() {
  local response=""
  local remaining=""
  local limit=""
  local reset=""
  local reset_display=""
  local required=""

  if ! response="$(github_api_rate_limit_response)"; then
    say "Error: could not read GitHub API rate limits through Cloudflare WARP." >&2
    return 1
  fi

  remaining="$(github_api_rate_limit_value "$response" remaining || true)"
  limit="$(github_api_rate_limit_value "$response" limit || true)"
  reset="$(github_api_rate_limit_value "$response" reset || true)"
  required="$(github_api_required_budget)"

  if [[ ! "$remaining" =~ ^[0-9]+$ || ! "$limit" =~ ^[0-9]+$ ||
    ! "$reset" =~ ^[0-9]+$ || ! "$required" =~ ^[0-9]+$ ]]; then
    say "Error: GitHub returned an unreadable API rate-limit response." >&2
    return 1
  fi

  reset_display="$(/bin/date -r "$reset" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || printf 'unknown')"
  if [[ "$remaining" -lt "$required" ]]; then
    say "Error: GitHub API rate limit through WARP is $remaining/$limit; this install requires at least $required." >&2
    say "Rate limit resets at $reset_display (epoch $reset). Rerun ./install.sh after that time." >&2
    return 1
  fi

  say "GitHub API rate limit through WARP: $remaining/$limit remaining (minimum required: $required)."
}

warp_app_installed() {
  [[ -d "$NETWORK_RESCUE_WARP_APP" ]]
}

warp_rescue_is_managed() {
  [[ -f "$NETWORK_RESCUE_MARKER" ]]
}

warp_is_active() {
  /usr/bin/curl --silent --show-error --connect-timeout 8 --max-time 20 \
    https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null |
    /usr/bin/grep -qx 'warp=on'
}

download_warp_package() {
  local destination="$1"

  /usr/bin/curl --fail --location --show-error \
    --connect-timeout 10 --max-time 900 \
    --retry 5 --retry-delay 2 --retry-all-errors \
    --output "$destination" "$NETWORK_RESCUE_WARP_DOWNLOAD_URL"
}

warp_package_signature() {
  /usr/sbin/pkgutil --check-signature "$1"
}

warp_package_is_trusted() {
  local package="$1"
  local signature=""

  if ! signature="$(warp_package_signature "$package" 2>&1)"; then
    return 1
  fi

  /usr/bin/grep -E \
    "Developer ID Installer: .+ \\($NETWORK_RESCUE_WARP_TEAM_ID\\)[[:space:]]*$" \
    <<<"$signature" >/dev/null
}

warp_app_is_trusted() {
  local signature=""

  if ! /usr/bin/codesign --verify --deep --strict \
    "$NETWORK_RESCUE_WARP_APP" >/dev/null 2>&1; then
    return 1
  fi

  if ! signature="$(/usr/bin/codesign -dv --verbose=4 "$NETWORK_RESCUE_WARP_APP" 2>&1)"; then
    return 1
  fi

  /usr/bin/grep -F "Identifier=$NETWORK_RESCUE_WARP_BUNDLE_ID" \
    <<<"$signature" >/dev/null &&
    /usr/bin/grep -F "TeamIdentifier=$NETWORK_RESCUE_WARP_TEAM_ID" \
      <<<"$signature" >/dev/null
}

run_warp_package_installer() {
  sudo_askpass /usr/sbin/installer -pkg "$1" -target /
}

mark_warp_rescue_managed() {
  /bin/mkdir -p "$(dirname "$NETWORK_RESCUE_MARKER")"
  /usr/bin/touch "$NETWORK_RESCUE_MARKER"
}

install_warp_rescue() {
  local package=""

  NETWORK_RESCUE_TEMP_DIR="$(/usr/bin/mktemp -d)"
  package="$NETWORK_RESCUE_TEMP_DIR/Cloudflare_WARP.pkg"
  at_exit "
/bin/rm -rf '${NETWORK_RESCUE_TEMP_DIR}'
  "

  say "Downloading the official Cloudflare WARP rescue package..."
  download_warp_package "$package"

  if ! warp_package_is_trusted "$package"; then
    say "Error: Cloudflare WARP package signature is not trusted; refusing to install it." >&2
    return 1
  fi

  say "Installing temporary Cloudflare WARP connectivity rescue..."
  run_warp_package_installer "$package"

  if ! warp_app_installed || ! warp_app_is_trusted; then
    say "Error: installed Cloudflare WARP application failed verification." >&2
    return 1
  fi

  mark_warp_rescue_managed
}

activate_warp_rescue() {
  local attempt=1

  if warp_is_active; then
    return 0
  fi

  /usr/bin/open "$NETWORK_RESCUE_WARP_APP"
  say "Cloudflare WARP does not require an account in consumer mode."
  say "Choose consumer WARP, accept its privacy notice, and connect the tunnel."

  while [[ "$attempt" -le 3 ]]; do
    printf '\033[1m? Press Return after Cloudflare WARP shows Connected.\033[0m '
    IFS= read -r _
    if warp_is_active; then
      return 0
    fi
    note "Cloudflare does not report warp=on yet. Check the app and try again."
    attempt=$((attempt + 1))
  done

  say "Error: Cloudflare WARP was not activated." >&2
  return 1
}

ensure_bootstrap_connectivity() {
  section "Connectivity rescue"
  say "Cloudflare WARP protects every networked phase of this install."

  if warp_app_installed; then
    if ! warp_app_is_trusted; then
      say "Error: the existing Cloudflare WARP application has an unexpected signature; refusing to open it." >&2
      return 1
    fi
  else
    if ! is_interactive; then
      say "Error: Cloudflare WARP must be installed interactively before this install can continue." >&2
      return 1
    fi
    install_warp_rescue
  fi

  if ! warp_is_active && ! is_interactive; then
    say "Error: connect Cloudflare WARP, then rerun ./install.sh." >&2
    return 1
  fi

  activate_warp_rescue

  if ! github_connectivity_available; then
    say "Error: GitHub is still not reliably reachable through Cloudflare WARP." >&2
    return 1
  fi

  github_api_budget_available

  say "GitHub connectivity recovered through Cloudflare WARP."
}

uninstall_warp_rescue() {
  local resources="$NETWORK_RESCUE_WARP_APP/Contents/Resources"

  if ! warp_app_installed; then
    /bin/rm -f "$NETWORK_RESCUE_MARKER"
    return 0
  fi

  if [[ ! -x "$resources/uninstall.sh" ]]; then
    say "Error: Cloudflare WARP uninstall script is unavailable." >&2
    return 1
  fi

  (
    cd "$resources" || exit 1
    sudo_askpass ./uninstall.sh -f
  )
  /bin/rm -f "$NETWORK_RESCUE_MARKER"
}

finish_network_rescue() {
  warp_rescue_is_managed || return 0

  section "Connectivity rescue cleanup"
  say "Removing the temporary Cloudflare WARP installation..."
  uninstall_warp_rescue
}
