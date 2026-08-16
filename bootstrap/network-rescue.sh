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
      say "Error: could not read GitHub API rate limits through Cloudflare WARP." >&2
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
      say "GitHub API through WARP: $remaining/$limit remaining; $phase needs $required core API requests."
      return 0
    fi

    reset_display="$(/bin/date -r "$reset" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || printf 'unknown')"
    if [[ "$limit" -lt "$required" ]]; then
      say "Error: GitHub API rate limit through WARP is $remaining/$limit; $phase needs $required core API requests." >&2
      say "Authenticated GitHub access is required for this phase; the anonymous limit cannot satisfy it." >&2
      say "Rate limit resets at $reset_display (epoch $reset), but waiting cannot raise this session's $limit-request limit." >&2
      return 1
    fi

    say "GitHub API through WARP is $remaining/$limit; $phase needs $required core API requests."
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
  if ! warp_is_active; then
    if ! is_interactive; then
      say "Error: Cloudflare WARP disconnected before $phase." >&2
      return 1
    fi
    note "Cloudflare WARP disconnected before $phase; reconnecting it now."
    activate_warp_rescue
  fi
  if ! github_connectivity_available; then
    say "Error: GitHub routes are not reliable enough to start $phase." >&2
    return 1
  fi
  say "$traffic_summary"
  github_api_budget_available "$phase" "$required"
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
