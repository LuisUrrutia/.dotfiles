#!/usr/bin/env bash

# GitHub preflight for macOS bootstrap runs. The root Bootstrapper owns
# orchestration; this file owns route probes and GitHub API budget checks.

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
      say "Error: could not read GitHub API rate limits." >&2
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
      say "GitHub API: $remaining/$limit remaining; $phase needs $required core API requests."
      return 0
    fi

    reset_display="$(/bin/date -r "$reset" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || printf 'unknown')"
    if [[ "$limit" -lt "$required" ]]; then
      say "Error: GitHub API rate limit is $remaining/$limit; $phase needs $required core API requests." >&2
      say "Authenticated GitHub access is required for this phase; the anonymous limit cannot satisfy it." >&2
      say "Rate limit resets at $reset_display (epoch $reset), but waiting cannot raise this session's $limit-request limit." >&2
      return 1
    fi

    say "GitHub API is $remaining/$limit; $phase needs $required core API requests."
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
  if ! github_connectivity_available; then
    say "Error: GitHub routes are not reliable enough to start $phase." >&2
    return 1
  fi
  say "$traffic_summary"
  github_api_budget_available "$phase" "$required"
}
