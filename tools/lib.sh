#!/usr/bin/env bash

# Shared library for tool install scripts

set -euo pipefail

# HOMEBREW_PREFIX is only required by the require_brew_* helpers (checked at
# call time), so this file stays sourceable before Homebrew is installed —
# the root installer loads it early for has_full_disk_access.
DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

# Check if a Homebrew binary exists, warn and exit 0 if not
# Usage: require_brew_bin <binary_name>
# Sets: bin_path variable with full path to binary
require_brew_bin() {
  local name="$1"
  bin_path="${HOMEBREW_PREFIX:?HOMEBREW_PREFIX is not set}/bin/${name}"
  if [[ ! -x "$bin_path" ]]; then
    echo "Warning: $name not found, skipping" >&2
    exit 0
  fi
}

# Usage: set_default_app_for_extensions <app_name> <bundle_id> <extensions...>
set_default_app_for_extensions() {
  local app_name="$1"
  local bundle_id="$2"
  shift 2

  require_brew_bin duti

  local association_status=0
  local extension handler verified attempt
  for extension in "$@"; do
    if ! "$bin_path" -s "$bundle_id" ".$extension" all; then
      echo "Warning: could not set $app_name as the default for .$extension" >&2
      association_status=1
      continue
    fi

    # Launch Services can briefly return the previous handler after a successful write.
    verified=false
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
      if handler="$("$bin_path" -x "$extension")" && [[ "${handler##*$'\n'}" == "$bundle_id" ]]; then
        verified=true
        break
      fi
      [[ "$attempt" -eq 10 ]] || sleep 1
    done
    if [[ "$verified" != true ]]; then
      echo "Warning: $app_name default association verification failed for .$extension" >&2
      association_status=1
    fi
  done

  return "$association_status"
}

# Load the complete mise-managed environment into the current Bash process.
# Use after tools/mise/install.sh so later installers never depend on a shell
# restart or interactive shell configuration.
load_mise_environment() {
  local mise_path="${HOMEBREW_PREFIX:?HOMEBREW_PREFIX is not set}/bin/mise"
  local mise_environment=""

  if [[ ! -x "$mise_path" ]]; then
    echo "Error: mise not found after its Tool Installer completed" >&2
    return 1
  fi

  if ! mise_environment="$("$mise_path" env -s bash)"; then
    echo "Error: mise could not provide the Bootstrapper environment" >&2
    return 1
  fi

  eval "$mise_environment"
}

# Check if a Homebrew opt package exists, warn and exit 0 if not
# Usage: require_brew_opt <package_name>
# Sets: opt_path variable with full path to package
require_brew_opt() {
  local name="$1"
  opt_path="${HOMEBREW_PREFIX:?HOMEBREW_PREFIX is not set}/opt/${name}"
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

# Check whether this terminal has Full Disk Access. ~/Library/Safari is
# TCC-protected; listing it only succeeds when the permission is granted.
has_full_disk_access() {
  /bin/ls "$HOME/Library/Safari" >/dev/null 2>&1
}

sudo_askpass() {
  if [[ "${DOTFILES_USE_SUDO_ASKPASS:-false}" == true && -n "${SUDO_ASKPASS:-}" && -x "$SUDO_ASKPASS" ]]; then
    if /usr/bin/sudo -A -v 2>/dev/null; then
      /usr/bin/sudo -A "$@"
      return
    fi

    DOTFILES_USE_SUDO_ASKPASS=false
    export DOTFILES_USE_SUDO_ASKPASS
    echo "Warning: SUDO_ASKPASS helper failed; falling back to interactive sudo." >&2
  fi

  /usr/bin/sudo -v
  /usr/bin/sudo "$@"
}

# Stow a tool's config directory into $HOME with --restow for idempotency.
# Default is per-file symlinks (--no-folding), so files an app creates at
# runtime stay in $HOME instead of landing inside the repo. Pass --fold to
# let Stow fold a whole tree into a single directory symlink.
# Usage: stow_config <tool_name> [--fold]
stow_config() {
  local tool="$1"
  local tool_dir="$DOTFILES/tools/$tool"

  if [[ ! -d "$tool_dir/config" ]]; then
    echo "Error: missing Stow package: $tool_dir/config" >&2
    exit 1
  fi

  if [[ "${2:-}" == "--fold" ]]; then
    stow -v --restow -d "$tool_dir" -t "$HOME" config
  else
    stow -v --restow --no-folding -d "$tool_dir" -t "$HOME" config
  fi
  echo "Stowed $tool config"
}
