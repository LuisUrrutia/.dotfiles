#!/usr/bin/env bash

# Shared library for tool install scripts

set -euo pipefail

: "${HOMEBREW_PREFIX:?HOMEBREW_PREFIX is not set}"
DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

# Check if a Homebrew binary exists, warn and exit 0 if not
# Usage: require_brew_bin <binary_name>
# Sets: bin_path variable with full path to binary
require_brew_bin() {
  local name="$1"
  bin_path="${HOMEBREW_PREFIX}/bin/${name}"
  if [[ ! -x "$bin_path" ]]; then
    echo "Warning: $name not found, skipping" >&2
    exit 0
  fi
}

# Check if a Homebrew opt package exists, warn and exit 0 if not
# Usage: require_brew_opt <package_name>
# Sets: opt_path variable with full path to package
require_brew_opt() {
  local name="$1"
  opt_path="${HOMEBREW_PREFIX}/opt/${name}"
  if [[ ! -d "$opt_path" ]]; then
    echo "Warning: $name not found, skipping" >&2
    exit 0
  fi
}

# Check if a macOS app exists in /Applications, warn and exit 0 if not
# Usage: require_app <app_name>
# Sets: app_path variable with full path to app
require_app() {
  local name="$1"
  app_path="/Applications/${name}.app"
  if [[ ! -d "$app_path" ]]; then
    echo "Warning: $name not found, skipping" >&2
    exit 0
  fi
}

# Check if a macOS app exists in /Applications (non-exiting)
# Usage: app_exists <app_name>
# Returns: 0 if exists, 1 if not
app_exists() {
  local name="$1"
  [[ -d "/Applications/${name}.app" ]]
}

# Run a tool's install script
# Usage: run_tool <tool_name>
run_tool() {
  local tool="$1"
  local script="$DOTFILES/tools/$tool/install.sh"
  if [[ -x "$script" ]]; then
    echo "Configuring $tool..."
    bash "$script"
  fi
}
