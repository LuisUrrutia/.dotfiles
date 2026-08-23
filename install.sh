#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES="${DOTFILES:-$SCRIPT_DIR}"

# shellcheck source=bootstrap/install-options.sh
# shellcheck disable=SC1091
source "$DOTFILES/bootstrap/install-options.sh"
# shellcheck source=bootstrap/profiles.sh
# shellcheck disable=SC1091
source "$DOTFILES/bootstrap/profiles.sh"
# shellcheck source=tools/catalog.sh
# shellcheck disable=SC1091
source "$DOTFILES/tools/catalog.sh"

MACHINES_DIR="$DOTFILES/machines"

# Machine state lives outside the repo so a re-clone or git clean does not
# re-trigger first-run tasks; the repo-local .installed path is the legacy spot.
INSTALLED_MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/installed"
LEGACY_INSTALLED_MARKER="$DOTFILES/.installed"

DRY_RUN=false
ARG_ALL_PROFILES=false
ARG_CORE_ONLY=false
ARG_PROFILE_LIST=""
ARG_NO_UPGRADE=false
FIRST_RUN=false
DETECTED_HARDWARE_HASH=""
HAS_MACHINE_CONFIG=false
MACHINE_ID=""
MACHINE_NAME=""
MACHINE_HOSTNAME=""
MACHINE_INSTALL_MODE=""
MACHINE_PROFILES=""
MACHINE_GIT_USER_NAME=""
MACHINE_GIT_USER_EMAIL=""
MACHINE_GIT_SIGNING_KEY=""
MACHINE_GIT_SIGNING_PROGRAM=""
ALL_PROFILES=false
RUN_CLEANUP=false
RUN_BREW_UPGRADE=true
RUN_TOOL_INSTALLERS=true
RUN_XCODE_SETUP=false
RUN_FISH_SETUP=false
RUN_PROJECTS_SETUP=false
TOOLS_LIB_LOADED=false
PROFILE_ORDER=() # populated from brewfiles/profiles/ by init_profile_order
LANGUAGE_ORDER=(go lua rust perl)
SELECTED_PROFILES=()
SELECTED_LANGUAGES=()
SELECTED_PROFILE_PACKAGES=()
AT_EXIT=""
SUDO_ASKPASS=""
SUDO_ASKPASS_DIR=""
SUDO_ASKPASS_FIFO=""
SUDO_ASKPASS_BROKER_PID=""
SUDO_ASKPASS_BROKER_PID_FILE=""
SUDO_ASKPASS_PASSWORD=""
DOTFILES_USE_SUDO_ASKPASS=false
SUDO_KEEPALIVE_PID=""
SELECTED_PROFILE_BREWFILE=""
BREW_BUNDLE_FAILURES=()
BREW_BUNDLE_MAX_ATTEMPTS=5
BREW_CURL_RETRIES=5
SUDO_ASKPASS_MAX_ATTEMPTS=3
SUDO_ASKPASS_RESPONSE_TIMEOUT_SECONDS=5
HOMEBREW_INSTALL_COMMIT="f4aa1b1ca5b256954dbde0315455fb259cdfc45a"
HOMEBREW_INSTALL_SHA256="12479a24be3f5307eecac7cde670fad7118640f031229e964f544b1367b52a41"
HOMEBREW_INSTALL_CURL="${HOMEBREW_INSTALL_CURL:-/usr/bin/curl}"
HOMEBREW_INSTALL_SHASUM="${HOMEBREW_INSTALL_SHASUM:-/usr/bin/shasum}"

usage() {
  local profile=""

  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  -n, --dry-run          Show the install plan without changing the system
      --all-profiles     Install every optional profile
      --core-only        Install only core packages
      --profile LIST     Install selected profiles (comma-separated, repeatable)
      --no-upgrade       Skip updating/upgrading already-installed Homebrew packages
  -h, --help             Show this help

Profile flags for scripted installs:
EOF

  for profile in "${PROFILE_ORDER[@]}"; do
    printf '  %-22s %s\n' "$profile" "$(profile_metadata "$profile" summary)"
  done

  cat <<'EOF'

Examples:
  ./install.sh --dry-run
  ./install.sh --dry-run --profile web3,streaming,audio
  ./install.sh --core-only
EOF
}

say() {
  printf '%s\n' "$*"
}

machash() {
  bash "$DOTFILES/tools/bin/config/.local/bin/machash"
}

detected_hardware_hash() {
  local override="${DOTFILES_HARDWARE_HASH_OVERRIDE:-}"

  if [[ "$DRY_RUN" == true && -n "$override" ]]; then
    printf '%s' "$override"
    return 0
  fi

  machash
}

reset_machine_config() {
  MACHINE_ID=""
  MACHINE_NAME=""
  MACHINE_HOSTNAME=""
  MACHINE_INSTALL_MODE=""
  MACHINE_PROFILES=""
  MACHINE_GIT_USER_NAME=""
  MACHINE_GIT_USER_EMAIL=""
  MACHINE_GIT_SIGNING_KEY=""
  MACHINE_GIT_SIGNING_PROGRAM=""
}

# Source one machines/<hash>.sh file on top of fresh MACHINE_* values
load_machine_file() {
  reset_machine_config
  # shellcheck disable=SC1090
  source "$1"
}

load_active_machine() {
  local hardware_hash="${1:-}"
  local machine_file=""

  HAS_MACHINE_CONFIG=false
  reset_machine_config

  [[ -n "$hardware_hash" ]] || return 0
  machine_file="$MACHINES_DIR/$hardware_hash.sh"
  [[ -r "$machine_file" ]] || return 0

  load_machine_file "$machine_file"
  HAS_MACHINE_CONFIG=true
}

blank() {
  printf '\n'
}

section() {
  printf '\n\033[1;36m== %s ==\033[0m\n' "$*"
}

subsection() {
  printf '\033[1m-- %s\033[0m\n' "$*"
}

note() {
  printf '\033[0;33mNote:\033[0m %s\n' "$*"
}

plan_value() {
  local label="$1"
  local value="$2"

  printf '  %-32s %s\n' "$label" "$value"
}

is_interactive() {
  [[ -t 0 && -t 1 ]]
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local suffix="[y/N]"
  local response=""

  if [[ "$default" == "y" ]]; then
    suffix="[Y/n]"
  fi

  if ! is_interactive; then
    [[ "$default" == "y" ]]
    return
  fi

  blank
  printf '\033[1m? %s\033[0m %s ' "$prompt" "$suffix"
  read -r response
  case "$response" in
  [yY] | [yY][eE][sS])
    return 0
    ;;
  [nN] | [nN][oO])
    return 1
    ;;
  "")
    [[ "$default" == "y" ]]
    ;;
  *)
    note "Please answer yes or no."
    ask_yes_no "$prompt" "$default"
    ;;
  esac
}

check_full_disk_access() {
  if has_full_disk_access; then
    return 0
  fi

  section "Full Disk Access"
  say "This terminal lacks Full Disk Access, which sandboxed app settings (Safari, Messages) need."
  say "macOS requires restarting the terminal after granting it, so it's best to sort this out"
  say "now instead of re-running the whole install later."

  if ! is_interactive; then
    note "Non-interactive run: continuing; sandboxed app settings will be skipped."
    return 0
  fi

  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true
  say "System Settings should now be open at Privacy & Security > Full Disk Access."

  if ask_yes_no "Exit to grant Full Disk Access? (grant it, restart your terminal, re-run ./install.sh)" "y"; then
    exit 0
  fi

  note "Continuing without Full Disk Access; sandboxed app settings will be skipped."
}

has_xcode_command_line_tools() {
  /usr/bin/xcrun --find clang >/dev/null 2>&1
}

request_xcode_command_line_tools() {
  /usr/bin/xcode-select --install
}

ensure_xcode_command_line_tools() {
  if has_xcode_command_line_tools; then
    return 0
  fi

  section "Xcode Command Line Tools"
  say "Xcode Command Line Tools are required before Homebrew and the rest of the bootstrap."

  if ! is_interactive; then
    say "Error: install Xcode Command Line Tools with 'xcode-select --install', then rerun ./install.sh." >&2
    return 1
  fi

  if request_xcode_command_line_tools; then
    say "Apple's Command Line Tools installer is now open."
  else
    note "The installer may already be open. Finish it before continuing."
  fi
  say "Finish the installation, then rerun ./install.sh."
  exit 0
}

xcode_developer_dir() {
  printf '%s\n' '/Applications/Xcode.app/Contents/Developer'
}

setup_full_xcode() {
  local developer_dir=""

  section "Xcode"
  brew install mas
  if ! mas install 497799835; then
    note "mas could not install Xcode (are you signed in to the App Store?); skipping Xcode setup."
    note "Install Xcode from the App Store, then rerun ./install.sh."
    return 0
  fi

  developer_dir="$(xcode_developer_dir)"
  if [[ ! -d "$developer_dir" ]]; then
    say "Error: Xcode installation completed but its Developer directory is missing: $developer_dir" >&2
    return 1
  fi

  sudo_askpass /usr/bin/xcode-select --switch "$developer_dir"
  sudo_askpass /usr/bin/xcodebuild -license accept
  sudo_askpass /usr/bin/xcodebuild -runFirstLaunch
}

at_exit() {
  AT_EXIT+="${AT_EXIT:+$'\n'}"
  AT_EXIT+="${*?}"
  # shellcheck disable=SC2064
  trap "${AT_EXIT}" EXIT
}

# shellcheck disable=SC1091
source "$DOTFILES/bootstrap/github-preflight.sh"

parse_args() {
  if ! parse_install_options "$@"; then
    say "Error: $INSTALL_OPTION_ERROR" >&2
    usage >&2
    exit 2
  fi
  if [[ "$INSTALL_OPTION_HELP" == true ]]; then
    usage
    exit 0
  fi

  DRY_RUN="$INSTALL_OPTION_DRY_RUN"
  ARG_ALL_PROFILES="$INSTALL_OPTION_ALL_PROFILES"
  ARG_CORE_ONLY="$INSTALL_OPTION_CORE_ONLY"
  ARG_PROFILE_LIST="$INSTALL_OPTION_PROFILE_LIST"
  ARG_NO_UPGRADE="$INSTALL_OPTION_NO_UPGRADE"
}

# Shared Brewfile entry parser. Calls <callback> once per package entry with:
#   $1 kind, $2 name, $3 description (trailing comment), $4 original line
# Callbacks run in the current shell and communicate through the
# BREWFILE_ENTRY_* globals below.
BREWFILE_ENTRY_FILTER=()
BREWFILE_ENTRY_INDENT="  "
BREWFILE_ENTRY_MATCHED=false
BREWFILE_ENTRY_NAMES=()
BREWFILE_ENTRY_DESCRIPTIONS=()

each_brewfile_entry() {
  local brewfile="$1"
  local callback="$2"
  local line=""
  local kind=""
  local name=""
  local rest=""
  local description=""

  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*(brew|cask|tap|mas|vscode)[[:space:]]+\"([^\"]+)\"(.*)$ ]] || continue
    kind="${BASH_REMATCH[1]}"
    name="${BASH_REMATCH[2]}"
    rest="${BASH_REMATCH[3]}"
    description=""

    if [[ "$rest" == *#* ]]; then
      description="${rest#*#}"
      description="${description#"${description%%[![:space:]]*}"}"
    fi

    "$callback" "$kind" "$name" "$description" "$line"
  done <"$brewfile"
}

print_brewfile_entry_row() {
  local kind="$1"
  local name="$2"
  local description="$3"

  if ((${#BREWFILE_ENTRY_FILTER[@]} > 0)) && ! array_contains "$name" "${BREWFILE_ENTRY_FILTER[@]}"; then
    return
  fi

  if [[ -n "$description" ]]; then
    printf '%s%-6s %-31s %s\n' "$BREWFILE_ENTRY_INDENT" "$kind" "$name" "$description"
  else
    printf '%s%-6s %-31s\n' "$BREWFILE_ENTRY_INDENT" "$kind" "$name"
  fi
  BREWFILE_ENTRY_MATCHED=true
}

collect_brewfile_entry() {
  BREWFILE_ENTRY_NAMES+=("$2")
  BREWFILE_ENTRY_DESCRIPTIONS+=("$3")
}

emit_matching_brewfile_line() {
  local name="$2"
  local line="$4"

  if array_contains "$name" "${BREWFILE_ENTRY_FILTER[@]}"; then
    printf '%s\n' "$line"
  fi
}

print_profile_packages() {
  local profile="$1"
  local indent="$2"
  shift 2

  local profile_file=""

  BREWFILE_ENTRY_FILTER=("$@")
  BREWFILE_ENTRY_INDENT="$indent"
  BREWFILE_ENTRY_MATCHED=false

  profile_file="$(profile_brewfile "$profile")"
  say "${indent}Type   Package                         Notes"
  say "${indent}----   -------                         -----"
  each_brewfile_entry "$profile_file" print_brewfile_entry_row

  if [[ "$BREWFILE_ENTRY_MATCHED" != true ]]; then
    say "${indent}(no matching packages)"
  fi
}

ask_profile_package_questions() {
  local profile="$1"
  local profile_file=""
  local prompt=""
  local i=0

  profile_file="$(profile_brewfile "$profile")"
  BREWFILE_ENTRY_NAMES=()
  BREWFILE_ENTRY_DESCRIPTIONS=()
  each_brewfile_entry "$profile_file" collect_brewfile_entry

  for ((i = 0; i < ${#BREWFILE_ENTRY_NAMES[@]}; i++)); do
    prompt="Install ${BREWFILE_ENTRY_NAMES[$i]}"
    if [[ -n "${BREWFILE_ENTRY_DESCRIPTIONS[$i]}" ]]; then
      prompt+=" (${BREWFILE_ENTRY_DESCRIPTIONS[$i]})"
    fi
    prompt+="?"

    if ask_yes_no "$prompt" "y"; then
      add_profile_package "$profile" "${BREWFILE_ENTRY_NAMES[$i]}"
    fi
  done
}

language_label() {
  case "$1" in
  go) say "Go" ;;
  lua) say "Lua" ;;
  rust) say "Rust" ;;
  perl) say "Perl" ;;
  *) return 1 ;;
  esac
}

language_packages() {
  case "$1" in
  go)
    say "go"
    ;;
  lua)
    say "lua"
    say "luarocks"
    ;;
  rust)
    say "rustup"
    ;;
  perl)
    say "perl"
    say "cpanm"
    ;;
  *)
    return 1
    ;;
  esac
}

language_selected() {
  ((${#SELECTED_LANGUAGES[@]} > 0)) || return 1
  array_contains "$1" "${SELECTED_LANGUAGES[@]}"
}

add_language() {
  local language="$1"

  language_label "$language" >/dev/null || {
    say "Error: unknown language: $language" >&2
    exit 1
  }

  if ! language_selected "$language"; then
    SELECTED_LANGUAGES+=("$language")
  fi
}

profile_package_selected() {
  local profile="$1"
  local package_name="$2"

  ((${#SELECTED_PROFILE_PACKAGES[@]} > 0)) || return 1
  array_contains "$profile:$package_name" "${SELECTED_PROFILE_PACKAGES[@]}"
}

add_profile_package() {
  local profile="$1"
  local package_name="$2"

  if ! profile_package_selected "$profile" "$package_name"; then
    SELECTED_PROFILE_PACKAGES+=("$profile:$package_name")
  fi
}

selected_profile_package_names() {
  local profile="$1"
  local selected=""

  ((${#SELECTED_PROFILE_PACKAGES[@]} > 0)) || return 0

  for selected in "${SELECTED_PROFILE_PACKAGES[@]}"; do
    [[ "$selected" == "$profile:"* ]] || continue
    say "${selected#*:}"
  done
}

profile_has_selected_packages() {
  local profile="$1"
  local selected=""

  ((${#SELECTED_PROFILE_PACKAGES[@]} > 0)) || return 1

  for selected in "${SELECTED_PROFILE_PACKAGES[@]}"; do
    [[ "$selected" == "$profile:"* ]] && return 0
  done

  return 1
}

print_selected_language_packages() {
  local indent="${1:-  }"
  local language=""
  local package=""
  local packages=()

  for language in "${SELECTED_LANGUAGES[@]}"; do
    while IFS= read -r package; do
      packages+=("$package")
    done < <(language_packages "$language")
  done

  print_profile_packages "languages" "$indent" "${packages[@]}"
}

profile_selected() {
  ((${#SELECTED_PROFILES[@]} > 0)) || return 1
  array_contains "$1" "${SELECTED_PROFILES[@]}"
}

add_profile() {
  local profile="$1"
  local brewfile=""

  profile_exists "$profile" || {
    say "Error: unknown profile: $profile" >&2
    exit 1
  }

  brewfile="$(profile_brewfile "$profile")"
  if [[ ! -f "$brewfile" ]]; then
    say "Error: missing Brewfile for profile '$profile': $brewfile" >&2
    exit 1
  fi

  if ! profile_selected "$profile"; then
    SELECTED_PROFILES+=("$profile")
  fi
}

parse_profiles() {
  local raw_list="$1"
  local raw_profiles=()
  local raw_profile=""
  local profile=""

  IFS=',' read -r -a raw_profiles <<<"$raw_list"
  ((${#raw_profiles[@]} > 0)) || return 0
  for raw_profile in "${raw_profiles[@]}"; do
    [[ -n "$raw_profile" ]] || continue
    if ! profile="$(normalize_profile "$raw_profile")"; then
      say "Error: unknown profile: $raw_profile" >&2
      exit 1
    fi
    add_profile "$profile"
  done
}

ask_profile_questions() {
  local default="$1"
  local profile=""
  local question=""
  local label=""

  for profile in "${PROFILE_ORDER[@]}"; do
    if [[ "$profile" == "languages" ]]; then
      ask_language_questions "$default"
      continue
    fi

    question="$(profile_question "$profile")"
    label="$(profile_label "$profile")"
    blank
    subsection "$profile - $label"
    print_profile_packages "$profile" "  "
    if ask_yes_no "$question" "$default"; then
      ask_profile_package_questions "$profile"
      if profile_has_selected_packages "$profile"; then
        add_profile "$profile"
      fi
    fi
  done
}

ask_language_questions() {
  local default="$1"
  local language=""
  local language_name=""
  local package=""
  local packages=()

  for language in "${LANGUAGE_ORDER[@]}"; do
    language_name="$(language_label "$language")"
    packages=()
    while IFS= read -r package; do
      packages+=("$package")
    done < <(language_packages "$language")

    blank
    subsection "$language_name tools"
    print_profile_packages "languages" "  " "${packages[@]}"
    if ask_yes_no "Install $language_name tools?" "$default"; then
      add_language "$language"
    fi
  done

  if ((${#SELECTED_LANGUAGES[@]} > 0)); then
    add_profile "languages"
  fi
}

detect_state() {
  if [[ -f "$INSTALLED_MARKER" || -f "$LEGACY_INSTALLED_MARKER" ]]; then
    FIRST_RUN=false
  else
    FIRST_RUN=true
  fi

  if ! DETECTED_HARDWARE_HASH="$(detected_hardware_hash 2>/dev/null)"; then
    DETECTED_HARDWARE_HASH=""
    note "Hardware hash detection failed; treating this machine as unregistered."
  fi
  load_active_machine "$DETECTED_HARDWARE_HASH"
}

configure_machine_environment() {
  local i=0
  local managed_identity_count=0
  local name_var=""
  local email_var=""
  local signing_key_var=""
  local signing_program_var=""
  local machine_file=""

  for ((i = 1; i <= ${DOTFILES_MANAGED_GIT_IDENTITY_COUNT:-0}; i++)); do
    unset "DOTFILES_MANAGED_GIT_USER_NAME_$i" "DOTFILES_MANAGED_GIT_USER_EMAIL_$i" "DOTFILES_MANAGED_GIT_SIGNING_KEY_$i" "DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_$i"
  done

  for machine_file in "$MACHINES_DIR"/*.sh; do
    [[ -f "$machine_file" ]] || continue
    load_machine_file "$machine_file"
    if [[ -z "$MACHINE_GIT_USER_NAME" && -z "$MACHINE_GIT_USER_EMAIL" && -z "$MACHINE_GIT_SIGNING_KEY" && -z "$MACHINE_GIT_SIGNING_PROGRAM" ]]; then
      continue
    fi

    managed_identity_count=$((managed_identity_count + 1))
    name_var="DOTFILES_MANAGED_GIT_USER_NAME_$managed_identity_count"
    email_var="DOTFILES_MANAGED_GIT_USER_EMAIL_$managed_identity_count"
    signing_key_var="DOTFILES_MANAGED_GIT_SIGNING_KEY_$managed_identity_count"
    signing_program_var="DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_$managed_identity_count"

    printf -v "$name_var" '%s' "$MACHINE_GIT_USER_NAME"
    printf -v "$email_var" '%s' "$MACHINE_GIT_USER_EMAIL"
    printf -v "$signing_key_var" '%s' "$MACHINE_GIT_SIGNING_KEY"
    printf -v "$signing_program_var" '%s' "$MACHINE_GIT_SIGNING_PROGRAM"
    export "${name_var?}" "${email_var?}" "${signing_key_var?}" "${signing_program_var?}"
  done

  export DOTFILES_MANAGED_GIT_IDENTITY_COUNT="$managed_identity_count"

  # The loop above clobbered MACHINE_*; restore this machine's values.
  load_active_machine "$DETECTED_HARDWARE_HASH"

  export DOTFILES_HAS_HARDWARE_PROFILE="$HAS_MACHINE_CONFIG"
  export DOTFILES_HARDWARE_PROFILE_ID="$MACHINE_ID"
  export DOTFILES_HARDWARE_PROFILE_NAME="$MACHINE_NAME"
  export DOTFILES_HARDWARE_HOSTNAME="$MACHINE_HOSTNAME"
  export DOTFILES_GIT_USER_NAME="$MACHINE_GIT_USER_NAME"
  export DOTFILES_GIT_USER_EMAIL="$MACHINE_GIT_USER_EMAIL"
  export DOTFILES_GIT_SIGNING_KEY="$MACHINE_GIT_SIGNING_KEY"
  export DOTFILES_GIT_SIGNING_PROGRAM="$MACHINE_GIT_SIGNING_PROGRAM"

  if [[ "$HAS_MACHINE_CONFIG" != true ]]; then
    return
  fi

  unset GIT_USER_NAME GIT_USER_EMAIL GIT_SIGNING_KEY GIT_SIGNING_PROGRAM

  if [[ -n "$MACHINE_GIT_USER_NAME" ]]; then
    export GIT_USER_NAME="$MACHINE_GIT_USER_NAME"
  fi
  if [[ -n "$MACHINE_GIT_USER_EMAIL" ]]; then
    export GIT_USER_EMAIL="$MACHINE_GIT_USER_EMAIL"
  fi
  if [[ -n "$MACHINE_GIT_SIGNING_KEY" ]]; then
    export GIT_SIGNING_KEY="$MACHINE_GIT_SIGNING_KEY"
  fi
  if [[ -n "$MACHINE_GIT_SIGNING_PROGRAM" ]]; then
    export GIT_SIGNING_PROGRAM="$MACHINE_GIT_SIGNING_PROGRAM"
  fi
}

configure_install_plan() {
  if [[ "$ARG_ALL_PROFILES" == true ]]; then
    ALL_PROFILES=true
    return
  fi

  if [[ "$ARG_CORE_ONLY" == true ]]; then
    ALL_PROFILES=false
    return
  fi

  if [[ -n "$ARG_PROFILE_LIST" ]]; then
    ALL_PROFILES=false
    parse_profiles "$ARG_PROFILE_LIST"
    return
  fi

  if [[ "$HAS_MACHINE_CONFIG" == true ]]; then
    case "$MACHINE_INSTALL_MODE" in
    all)
      ALL_PROFILES=true
      return
      ;;
    core)
      ALL_PROFILES=false
      return
      ;;
    selected)
      ALL_PROFILES=false
      if [[ -z "$MACHINE_PROFILES" ]]; then
        say "Error: selected install mode for machine '$MACHINE_ID' requires explicit profiles" >&2
        exit 1
      fi
      parse_profiles "$MACHINE_PROFILES"
      return
      ;;
    *)
      say "Error: invalid install mode for machine '$MACHINE_ID': $MACHINE_INSTALL_MODE" >&2
      exit 1
      ;;
    esac
  fi

  section "Optional tool selection"
  say "Core packages are always installed. Review each group, then answer yes only where useful."
  ask_profile_questions "n"
}

configure_cleanup_plan() {
  RUN_CLEANUP=false

  if ! is_interactive; then
    return
  fi

  section "Cleanup"
  if ask_yes_no "Clean up Homebrew packages not listed in the selected Brewfiles after install?" "n"; then
    RUN_CLEANUP=true
  fi
}

configure_system_plan() {
  RUN_TOOL_INSTALLERS=true
  RUN_BREW_UPGRADE=true

  if [[ "$ARG_NO_UPGRADE" == true ]]; then
    RUN_BREW_UPGRADE=false
  fi

  if [[ "$FIRST_RUN" == true ]]; then
    RUN_PROJECTS_SETUP=true
    RUN_XCODE_SETUP=true
    RUN_FISH_SETUP=true
  fi
}

profile_mode() {
  if [[ "$ALL_PROFILES" == true ]]; then
    say "all"
  elif ((${#SELECTED_PROFILES[@]} > 0)); then
    say "selected"
  else
    say "core"
  fi
}

print_selected_profiles() {
  local profile=""
  local label=""
  local package=""
  local packages=()

  if [[ "$ALL_PROFILES" == true ]]; then
    say "  all optional tool groups"
    for profile in "${PROFILE_ORDER[@]}"; do
      label="$(profile_label "$profile")"
      say "  $profile - $label"
      print_profile_packages "$profile" "      "
    done
    return
  fi

  if ((${#SELECTED_PROFILES[@]} == 0)); then
    say "  none"
    return
  fi

  for profile in "${SELECTED_PROFILES[@]}"; do
    label="$(profile_label "$profile")"
    say "  $profile - $label"
    if [[ "$profile" == "languages" && ${#SELECTED_LANGUAGES[@]} -gt 0 ]]; then
      say "    Languages: ${SELECTED_LANGUAGES[*]}"
      print_selected_language_packages "    "
    elif profile_has_selected_packages "$profile"; then
      packages=()
      while IFS= read -r package; do
        packages+=("$package")
      done < <(selected_profile_package_names "$profile")
      print_profile_packages "$profile" "    " "${packages[@]}"
    else
      print_profile_packages "$profile" "    "
    fi
  done
}

list_tool_installers() {
  local tool_dir=""
  local tool_name=""

  if [[ -x "$DOTFILES/tools/mise/install.sh" ]]; then
    say "  - mise"
  fi

  for tool_dir in "$DOTFILES/tools"/*; do
    [[ -d "$tool_dir" ]] || continue
    tool_name="$(basename "$tool_dir")"
    [[ "$tool_name" == "fish" || "$tool_name" == "mise" ]] && continue
    [[ -x "$tool_dir/install.sh" ]] || continue
    say "  - $tool_name"
  done
}

print_install_plan() {
  local brew_missing="no"
  local mode="real"
  local profile_brewfile="none"

  if ! command -v brew >/dev/null 2>&1 && [[ ! -x "/opt/homebrew/bin/brew" ]]; then
    brew_missing="yes"
  fi

  if [[ "$DRY_RUN" == true ]]; then
    mode="dry-run"
  fi

  if [[ "$ALL_PROFILES" == true ]]; then
    profile_brewfile="temporary Brewfile from all profile files"
  elif ((${#SELECTED_PROFILES[@]} > 0)); then
    profile_brewfile="temporary Brewfile from selected profile files"
  fi

  section "Install plan"
  subsection "Run context"
  plan_value "Mode" "$mode"
  plan_value "Dotfiles" "$DOTFILES"
  if [[ "$HAS_MACHINE_CONFIG" == true ]]; then
    plan_value "Machine config" "${MACHINE_ID:-registered}"
    plan_value "Machine install mode" "$MACHINE_INSTALL_MODE"
  else
    plan_value "Machine config" "unregistered"
  fi
  plan_value "First run" "$FIRST_RUN"
  if has_full_disk_access; then
    plan_value "Full Disk Access" "granted"
  else
    plan_value "Full Disk Access" "missing (sandboxed app settings would be skipped)"
  fi
  if has_xcode_command_line_tools; then
    plan_value "Xcode Command Line Tools" "installed"
  else
    plan_value "Xcode Command Line Tools" "missing (required before installation)"
  fi

  subsection "Brewfiles"
  plan_value "Core Brewfile" "$DOTFILES/brewfiles/core"
  plan_value "Profile Brewfile" "$profile_brewfile"

  subsection "Optional tool groups"
  plan_value "Profile mode" "$(profile_mode)"
  print_selected_profiles

  subsection "Planned actions"
  plan_value "Install Homebrew" "$brew_missing"
  if [[ "$brew_missing" == "yes" ]]; then
    plan_value "Upgrade existing packages" "n/a (installing Homebrew)"
  else
    plan_value "Upgrade existing packages" "$RUN_BREW_UPGRADE"
  fi
  plan_value "Full Xcode app setup" "$RUN_XCODE_SETUP"
  plan_value "Run Homebrew cleanup" "$RUN_CLEANUP"
  plan_value "Tool configs/macOS settings" "$RUN_TOOL_INSTALLERS"
  plan_value "Fish setup" "$RUN_FISH_SETUP"
  plan_value "Projects directory" "$RUN_PROJECTS_SETUP"
  plan_value "Mark install complete" "if no package failures"

  subsection "Tool config/setup scripts"
  list_tool_installers

  if [[ "$DRY_RUN" == true ]]; then
    note "Dry run: exiting before sudo, credential broker, Homebrew, mas, cleanup, Stow, chsh, mkdir, or install-marker changes."
  fi
}

create_profile_brewfile() {
  local output="$1"
  shift

  local profiles=("$@")
  local profile=""
  local profile_file=""
  local language=""
  local package=""

  : >"$output"
  for profile in "${profiles[@]}"; do
    profile_file="$(profile_brewfile "$profile")"

    if [[ ! -f "$profile_file" ]]; then
      say "Error: missing Brewfile for profile '$profile': $profile_file" >&2
      exit 1
    fi

    if ! grep -Eq '^[[:space:]]*(brew|cask|tap|mas|vscode)[[:space:]]' "$profile_file"; then
      say "Error: no Brewfile entries found for profile '$profile': $profile_file" >&2
      exit 1
    fi

    BREWFILE_ENTRY_FILTER=()
    if [[ "$profile" == "languages" && ${#SELECTED_LANGUAGES[@]} -gt 0 ]]; then
      for language in "${SELECTED_LANGUAGES[@]}"; do
        while IFS= read -r package; do
          BREWFILE_ENTRY_FILTER+=("$package")
        done < <(language_packages "$language")
      done
    elif profile_has_selected_packages "$profile"; then
      while IFS= read -r package; do
        BREWFILE_ENTRY_FILTER+=("$package")
      done < <(selected_profile_package_names "$profile")
    fi

    {
      printf '# %s\n' "$profile_file"
      if ((${#BREWFILE_ENTRY_FILTER[@]} > 0)); then
        each_brewfile_entry "$profile_file" emit_matching_brewfile_line
      else
        cat "$profile_file"
      fi
      printf '\n'
    } >>"$output"
  done

  if ! grep -Eq '^[[:space:]]*(brew|cask|tap|mas|vscode)[[:space:]]' "$output"; then
    say "Error: selected profile Brewfile has no package entries" >&2
    exit 1
  fi
}

load_homebrew() {
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
  fi
}

capture_sudo_password() {
  IFS= builtin read -r -s -p "Password: " SUDO_ASKPASS_PASSWORD
  printf "\n"
}

sudo_password_broker_running() {
  local recorded_pid=""

  [[ -n "$SUDO_ASKPASS_BROKER_PID" ]] || return 1
  [[ -r "$SUDO_ASKPASS_BROKER_PID_FILE" ]] || return 1
  IFS= read -r recorded_pid <"$SUDO_ASKPASS_BROKER_PID_FILE" || return 1
  [[ "$recorded_pid" == "$SUDO_ASKPASS_BROKER_PID" ]] || return 1
  /bin/kill -0 "$SUDO_ASKPASS_BROKER_PID" >/dev/null 2>&1
}

stop_sudo_password_broker() {
  local broker_pid="$SUDO_ASKPASS_BROKER_PID"

  if [[ -n "$SUDO_ASKPASS_BROKER_PID_FILE" ]]; then
    /bin/rm -f "$SUDO_ASKPASS_BROKER_PID_FILE"
  fi
  if [[ -n "$broker_pid" ]]; then
    /bin/kill "$broker_pid" >/dev/null 2>&1 || true
    wait "$broker_pid" 2>/dev/null || true
  fi
  SUDO_ASKPASS_BROKER_PID=""
}

cleanup_sudo_askpass_transport() {
  local askpass_dir="$SUDO_ASKPASS_DIR"

  stop_sudo_password_broker
  if [[ -d "$askpass_dir" ]]; then
    case "$askpass_dir" in
    */dotfiles-askpass.*) /bin/rm -rf "$askpass_dir" ;;
    *)
      printf 'Error: refusing to remove unexpected SUDO_ASKPASS directory: %s\n' \
        "$askpass_dir" >&2
      return 1
      ;;
    esac
  fi
}

start_sudo_password_broker() {
  local password="$1"

  stop_sudo_password_broker
  (
    trap 'exit 0' HUP INT TERM
    trap '' PIPE
    while true; do
      if ! printf '%s\n' "$password" 2>/dev/null >"$SUDO_ASKPASS_FIFO"; then
        [[ -p "$SUDO_ASKPASS_FIFO" ]] || exit 0
      fi
    done
  ) &
  SUDO_ASKPASS_BROKER_PID="$!"
  if ! printf '%s\n' "$SUDO_ASKPASS_BROKER_PID" \
    >"$SUDO_ASKPASS_BROKER_PID_FILE" ||
    ! /bin/chmod 600 "$SUDO_ASKPASS_BROKER_PID_FILE"; then
    stop_sudo_password_broker
    return 1
  fi
}

initialize_sudo_askpass_transport() {
  if [[ ! "$SUDO_ASKPASS_RESPONSE_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Error: invalid SUDO_ASKPASS response timeout: %s\n' \
      "$SUDO_ASKPASS_RESPONSE_TIMEOUT_SECONDS" >&2
    return 1
  fi

  SUDO_ASKPASS_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/dotfiles-askpass.XXXXXX")"
  SUDO_ASKPASS_FIFO="$SUDO_ASKPASS_DIR/password"
  SUDO_ASKPASS_BROKER_PID_FILE="$SUDO_ASKPASS_DIR/broker-pid"
  SUDO_ASKPASS="$SUDO_ASKPASS_DIR/askpass"

  /bin/chmod 700 "$SUDO_ASKPASS_DIR"
  /usr/bin/mkfifo "$SUDO_ASKPASS_FIFO"
  /bin/chmod 600 "$SUDO_ASKPASS_FIFO"

  {
    printf '%s\n' '#!/bin/sh'
    printf 'response_timeout=%s\n' "$SUDO_ASKPASS_RESPONSE_TIMEOUT_SECONDS"
    cat <<'EOF'
askpass_dir="$(CDPATH= cd "$(/usr/bin/dirname "$0")" && pwd)" || exit 1
lock_dir="$askpass_dir/reader-lock"
password_fifo="$askpass_dir/password"
broker_pid_file="$askpass_dir/broker-pid"

credential_broker_running() {
  broker_pid=""
  [ -r "$broker_pid_file" ] || return 1
  IFS= read -r broker_pid <"$broker_pid_file" || return 1
  case "$broker_pid" in
  '' | *[!0-9]*) return 1 ;;
  esac
  /bin/kill -0 "$broker_pid" >/dev/null 2>&1
}

attempt=0
while ! /bin/mkdir "$lock_dir" 2>/dev/null; do
  if ! credential_broker_running; then
    printf 'dotfiles askpass: credential broker is unavailable\n' >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 200 ]; then
    printf 'dotfiles askpass: timed out waiting for another credential reader\n' >&2
    exit 1
  fi
  /bin/sleep 0.05
done

cleanup() {
  /bin/rmdir "$lock_dir" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if ! credential_broker_running; then
  printf 'dotfiles askpass: credential broker is unavailable\n' >&2
  exit 1
fi

# Opening both ends prevents the shell from blocking before read can enforce
# its timeout. Only the broker writes, so this process cannot consume its own
# data.
if ! exec 3<>"$password_fifo"; then
  printf 'dotfiles askpass: credential channel is unavailable\n' >&2
  exit 1
fi
if ! IFS= read -r -t "$response_timeout" password <&3; then
  printf 'dotfiles askpass: credential broker did not respond\n' >&2
  exit 1
fi
exec 3>&-

printf '%s\n' "$password"
EOF
  } >"$SUDO_ASKPASS"

  /bin/chmod 700 "$SUDO_ASKPASS"
  export SUDO_ASKPASS

  at_exit "
cleanup_sudo_askpass_transport
  "
}

validate_sudo_askpass() {
  sudo_password_broker_running || return 1
  /usr/bin/sudo -A -kv 2>/dev/null
}

authenticate_sudo_askpass() {
  local attempt=1
  local restore_xtrace=false

  while [[ "$attempt" -le "$SUDO_ASKPASS_MAX_ATTEMPTS" ]]; do
    capture_sudo_password
    if [[ "$-" == *x* ]]; then
      restore_xtrace=true
      set +x
    fi
    start_sudo_password_broker "$SUDO_ASKPASS_PASSWORD"
    SUDO_ASKPASS_PASSWORD=""
    if [[ "$restore_xtrace" == true ]]; then
      set -x
      restore_xtrace=false
    fi
    if validate_sudo_askpass; then
      return 0
    fi

    stop_sudo_password_broker
    if [[ "$attempt" -lt "$SUDO_ASKPASS_MAX_ATTEMPTS" ]]; then
      printf 'Password was not accepted. Try again.\n' >&2
    fi
    attempt=$((attempt + 1))
  done

  printf 'Error: sudo password was not accepted after %s attempts.\n' \
    "$SUDO_ASKPASS_MAX_ATTEMPTS" >&2
  return 1
}

ensure_sudo_askpass_ready() {
  [[ "$DOTFILES_USE_SUDO_ASKPASS" == true ]] || return 0

  if validate_sudo_askpass; then
    return 0
  fi

  note "The temporary sudo credential is no longer available; please enter the password again."
  authenticate_sudo_askpass
}

setup_sudo_askpass() {
  initialize_sudo_askpass_transport
  printf "SUDO_ASKPASS: %s\n" "$SUDO_ASKPASS"

  authenticate_sudo_askpass
  DOTFILES_USE_SUDO_ASKPASS=true
  export DOTFILES_USE_SUDO_ASKPASS
}

start_install_caffeinate() {
  /usr/bin/caffeinate -dimu -w $$ &
}

prepare_install_session() {
  check_full_disk_access
  ensure_xcode_command_line_tools

  # Turn fatal signals into a normal exit so the at_exit cleanup
  # (credential broker, temporary files, temp Brewfiles) still runs.
  trap 'exit 129' HUP INT TERM

  start_install_caffeinate
  setup_sudo_askpass
  start_sudo_keepalive
}

start_sudo_keepalive() {
  [[ "$DOTFILES_USE_SUDO_ASKPASS" == true ]] || return

  (
    while true; do
      /usr/bin/sudo -A -v >/dev/null 2>&1 || exit 0
      /bin/sleep 60
    done
  ) &
  SUDO_KEEPALIVE_PID="$!"

  at_exit "
/bin/kill '${SUDO_KEEPALIVE_PID}' >/dev/null 2>&1 || true
  "
}

install_homebrew_from_official_commit() {
  local installer=""
  local actual_sha256=""
  local install_status=0

  installer="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")"
  at_exit "
/bin/rm -f '${installer}'
  "

  "$HOMEBREW_INSTALL_CURL" \
    --fail --location --silent --show-error \
    --proto '=https' --tlsv1.2 \
    --output "$installer" \
    "https://raw.githubusercontent.com/Homebrew/install/$HOMEBREW_INSTALL_COMMIT/install.sh"

  actual_sha256="$("$HOMEBREW_INSTALL_SHASUM" -a 256 "$installer" | /usr/bin/awk '{print $1}')"
  if [[ "$actual_sha256" != "$HOMEBREW_INSTALL_SHA256" ]]; then
    say "Error: downloaded Homebrew installer checksum did not match the pinned release." >&2
    return 1
  fi

  if NONINTERACTIVE=1 /bin/bash "$installer"; then
    install_status=0
  else
    install_status=$?
  fi
  /bin/rm -f "$installer"
  return "$install_status"
}

install_homebrew() {
  if ! command -v brew >/dev/null 2>&1 && [[ ! -x "/opt/homebrew/bin/brew" ]]; then
    say "Installing Homebrew..."
    install_homebrew_from_official_commit
    return
  fi

  load_homebrew
  if [[ "$RUN_BREW_UPGRADE" != true ]]; then
    say "Skipping Homebrew update/upgrade (--no-upgrade)."
    return
  fi

  say "Updating Homebrew..."
  brew update -q
  brew upgrade -q
}

install_packages() {
  local profiles=()
  local label=""
  local source_label=""

  section "Homebrew packages"
  run_brew_bundle_install "verification tools" "$DOTFILES/brewfiles/verification"
  run_brew_bundle_install "core packages" "$DOTFILES/brewfiles/core"

  if [[ "$ALL_PROFILES" == true ]]; then
    profiles=("${PROFILE_ORDER[@]}")
    label="optional profile packages"
    source_label="generated all-profiles Brewfile"
  elif ((${#SELECTED_PROFILES[@]} > 0)); then
    profiles=("${SELECTED_PROFILES[@]}")
    label="selected profile packages"
    source_label="generated selected-profiles Brewfile"
  else
    say "Skipping optional profile Brewfiles."
    return
  fi

  SELECTED_PROFILE_BREWFILE="$(mktemp)"
  at_exit "
/bin/rm -f '${SELECTED_PROFILE_BREWFILE}'
  "
  create_profile_brewfile "$SELECTED_PROFILE_BREWFILE" "${profiles[@]}"
  run_brew_bundle_install "$label" "$SELECTED_PROFILE_BREWFILE" "$source_label"
}

brew_bundle_failed() {
  ((${#BREW_BUNDLE_FAILURES[@]} > 0))
}

run_brew_bundle_install() {
  local label="$1"
  local brewfile="$2"
  local source_label="${3:-$brewfile}"
  local attempt=1
  local jobs="auto"
  local download_concurrency="${HOMEBREW_DOWNLOAD_CONCURRENCY:-auto}"

  while [[ "$attempt" -le "$BREW_BUNDLE_MAX_ATTEMPTS" ]]; do
    if [[ "$attempt" -eq "$BREW_BUNDLE_MAX_ATTEMPTS" ]]; then
      jobs="1"
      download_concurrency="1"
    fi

    github_phase_preflight "Homebrew $label" 0 \
      "Homebrew uses formulae.brew.sh, GHCR, vendor downloads, and Git taps; its exact HTTP count is dynamic and it reserves 0 GitHub core API requests." \
      "web git release"
    ensure_sudo_askpass_ready
    if HOMEBREW_CURL_RETRIES="${HOMEBREW_CURL_RETRIES:-$BREW_CURL_RETRIES}" \
      HOMEBREW_DOWNLOAD_CONCURRENCY="$download_concurrency" \
      brew bundle install --jobs="$jobs" --file "$brewfile"; then
      return 0
    fi

    if [[ "$attempt" -lt "$BREW_BUNDLE_MAX_ATTEMPTS" ]]; then
      note "Homebrew bundle failed for $label (attempt $attempt/$BREW_BUNDLE_MAX_ATTEMPTS); retrying unfinished entries."
      brew_bundle_retry_delay "$attempt"
    fi
    attempt=$((attempt + 1))
  done

  BREW_BUNDLE_FAILURES+=("$label: $source_label")
  note "Homebrew bundle failed for $label after $BREW_BUNDLE_MAX_ATTEMPTS attempts; continuing only with remaining Brewfiles."
}

brew_bundle_retry_delay() {
  local failed_attempt="$1"
  local delay=30

  case "$failed_attempt" in
  1) delay=5 ;;
  2) delay=10 ;;
  3) delay=20 ;;
  esac

  /bin/sleep "$delay"
}

print_brew_bundle_failures() {
  local failure=""

  brew_bundle_failed || return 0

  section "Homebrew bundle failures"
  say "Some Brewfiles still failed after retrying. Dependent setup was not run."
  for failure in "${BREW_BUNDLE_FAILURES[@]}"; do
    say "  - $failure"
  done
  say "Review the Homebrew output above, then rerun ./install.sh after fixing those packages."
}

install_declared_packages_and_dependents() {
  install_packages
  if brew_bundle_failed; then
    print_brew_bundle_failures
    return 1
  fi

  run_cleanup
  run_tool_installers
  run_first_run_tasks
}

run_cleanup() {
  local -a cleanup_args=()

  if [[ "$RUN_CLEANUP" != true ]]; then
    say "Skipping Homebrew cleanup."
    return
  fi

  if [[ -n "$SELECTED_PROFILE_BREWFILE" ]]; then
    cleanup_args+=(--file "$SELECTED_PROFILE_BREWFILE")
  else
    cleanup_args+=(--core-only)
  fi

  section "Homebrew cleanup"
  say "Previewing Brewfile cleanup..."
  bash "$DOTFILES/cleanup.sh" "${cleanup_args[@]}" || true
  bash "$DOTFILES/cleanup.sh" --force "${cleanup_args[@]}"
  brew cleanup --prune=all
}

load_tool_library() {
  if [[ "$TOOLS_LIB_LOADED" == true ]]; then
    return
  fi

  # shellcheck disable=SC1091
  source "$DOTFILES/tools/lib.sh"
  TOOLS_LIB_LOADED=true
}

run_mise_tool_installer() {
  local mise_status=0

  while :; do
    if run_tool "mise"; then
      return 0
    else
      mise_status=$?
    fi

    if ! github_api_rate_limit_exhausted; then
      return "$mise_status"
    fi
    note "mise exhausted GitHub's core API quota; waiting for its reset before retrying the incomplete toolchain."
    github_phase_preflight "mise retry" 1 \
      "mise keeps completed tools and will retry only the remaining toolchain work." \
      "web release"
  done
}

run_tool_installers() {
  local tool_name=""
  local mise_aqua_count=""
  local mise_github_count=""
  local tmux_git_sources=""
  local vim_git_sources=""
  local vim_parser_sources=""

  load_tool_library
  mkdir -p "$HOME/.config"

  # mise owns the shared runtime and portable CLI toolchain required by later
  # Tool Installers, so the Bootstrapper establishes it first.
  mise_aqua_count="$(mise_github_backend_count aqua)"
  mise_github_count="$(mise_github_backend_count github)"
  github_phase_preflight "mise" 1 \
    "mise will install $mise_aqua_count Aqua and $mise_github_count GitHub release tools; its shared version cache avoids most GitHub API calls." \
    "web release"
  run_mise_tool_installer
  load_mise_environment

  while IFS= read -r tool_name; do
    [[ "$tool_name" == "fish" || "$tool_name" == "mise" ]] && continue
    if [[ "$tool_name" == "tmux" ]]; then
      tmux_git_sources="$(tmux_github_git_source_count)"
      github_phase_preflight "Tmux plugins" 0 \
        "TPack will synchronize $tmux_git_sources Git repositories; Git transport does not consume GitHub core API requests." \
        "git"
    elif [[ "$tool_name" == "vim" ]]; then
      vim_git_sources="$(vim_github_git_source_count)"
      vim_parser_sources="$(vim_treesitter_parser_source_count)"
      github_phase_preflight "Vim plugins" 0 \
        "Neovim will synchronize $vim_git_sources Git repositories and $vim_parser_sources Treesitter parser sources; these do not reserve GitHub core API requests." \
        "git"
    fi
    run_tool "$tool_name"
  done < <(LC_ALL=C list_tools)
}

run_first_run_tasks() {
  if [[ "$FIRST_RUN" != true ]]; then
    return
  fi

  section "First-run setup"
  mkdir -p "$HOME/Projects"

  load_tool_library
  run_tool "fish"
}

print_next_steps() {
  if brew_bundle_failed; then
    say "Installation finished with Homebrew package failures."
  else
    say "Installation complete!"
  fi

  blank
  cat "$DOTFILES/POST_INSTALL.md"
}

configure_and_print_install_plan() {
  detect_state
  configure_machine_environment
  configure_install_plan
  configure_cleanup_plan
  configure_system_plan
  print_install_plan
}

main() {
  init_profile_order
  parse_args "$@"

  if [[ $EUID -eq 0 ]]; then
    say "This script should not be run as root" >&2
    exit 1
  fi

  if [[ "$(uname)" != "Darwin" ]]; then
    say "Invalid OS!" >&2
    exit 1
  fi

  load_tool_library

  if [[ "$DRY_RUN" == true ]]; then
    configure_and_print_install_plan
    exit 0
  fi

  prepare_install_session
  configure_and_print_install_plan
  load_homebrew
  github_phase_preflight "Homebrew bootstrap" 0 \
    "Homebrew bootstrap/update uses Git, formulae.brew.sh, and GHCR; it reserves 0 GitHub core API requests." \
    "web git release"
  install_homebrew
  load_homebrew
  load_tool_library

  if [[ "$RUN_XCODE_SETUP" == true ]]; then
    setup_full_xcode
  fi

  install_declared_packages_and_dependents

  mkdir -p "$(dirname "$INSTALLED_MARKER")"
  touch "$INSTALLED_MARKER"
  rm -f "$LEGACY_INSTALLED_MARKER"
  print_next_steps
}

# Allow tests to source this file without running the installer.
if [[ "${DOTFILES_INSTALL_NO_MAIN:-false}" != true ]]; then
  main "$@"
fi
