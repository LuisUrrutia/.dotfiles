#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES="${DOTFILES:-$SCRIPT_DIR}"

DOTFILES_HARDWARE_PROFILES=()
# shellcheck source=hardware-profiles.sh
# shellcheck disable=SC1091
if [[ -r "$DOTFILES/hardware-profiles.sh" ]]; then
  source "$DOTFILES/hardware-profiles.sh"
fi

DRY_RUN=false
ARG_ALL_PROFILES=false
ARG_CORE_ONLY=false
ARG_PROFILE_LIST=""
FIRST_RUN=false
HAS_HARDWARE_PROFILE=false
ACTIVE_HARDWARE_PROFILE_ID=""
ACTIVE_HARDWARE_PROFILE_NAME=""
ACTIVE_HARDWARE_PROFILE_HOSTNAME=""
ACTIVE_HARDWARE_PROFILE_INSTALL_MODE=""
ACTIVE_HARDWARE_PROFILE_PROFILES=""
ACTIVE_HARDWARE_PROFILE_GIT_USER_NAME=""
ACTIVE_HARDWARE_PROFILE_GIT_USER_EMAIL=""
ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_KEY=""
ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_PROGRAM=""
HARDWARE_PROFILE_RECORD_HASH=""
HARDWARE_PROFILE_RECORD_ID=""
HARDWARE_PROFILE_RECORD_NAME=""
HARDWARE_PROFILE_RECORD_HOSTNAME=""
HARDWARE_PROFILE_RECORD_INSTALL_MODE=""
HARDWARE_PROFILE_RECORD_PROFILE_LIST=""
HARDWARE_PROFILE_RECORD_GIT_USER_NAME=""
HARDWARE_PROFILE_RECORD_GIT_USER_EMAIL=""
HARDWARE_PROFILE_RECORD_GIT_SIGNING_KEY=""
HARDWARE_PROFILE_RECORD_GIT_SIGNING_PROGRAM=""
ALL_PROFILES=false
RUN_CLEANUP=false
RUN_TOOL_INSTALLERS=true
RUN_XCODE_SETUP=false
RUN_FISH_SETUP=false
RUN_PROJECTS_SETUP=false
TOOLS_LIB_LOADED=false
PROFILE_ORDER=(audio dev formatters languages web3 cloud image productivity streaming window)
LANGUAGE_ORDER=(go lua rust perl)
SELECTED_PROFILES=()
SELECTED_LANGUAGES=()
SELECTED_PROFILE_PACKAGES=()
AT_EXIT=""
SUDO_ASKPASS=""
DOTFILES_USE_SUDO_ASKPASS=false
SUDO_KEEPALIVE_PID=""
SELECTED_PROFILE_BREWFILE=""
BREW_BUNDLE_FAILURES=()

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  -n, --dry-run          Show the install plan without changing the system
      --all-profiles     Install every optional profile
      --core-only        Install only core packages
      --profile LIST     Install selected profiles (comma-separated)
  -h, --help             Show this help

Profile flags for scripted installs:
  audio                  Focusrite Control, Loopback, SoundSource
  dev                    Docker, Yaak, Android tools, app inspection
  formatters             shfmt, markdownlint, stylua, yamlfmt, biome
  languages              Go, Lua, Rust, Perl toolchains
  web3                   Solidity, Ethereum, Stellar, Foundry
  cloud                  AWS, Terraform, Cosign
  image                  ImageMagick, libvips, AVIF/JPEG libraries
  productivity           BusyCal
  streaming              Camo Studio, OBS, OBS scene automation
  window                 skhd

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
  local uuid=""

  uuid="$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F '"' '/IOPlatformUUID/ { print $4; exit }')"
  if [[ -z "$uuid" ]]; then
    say "Error: unable to read IOPlatformUUID" >&2
    return 1
  fi

  printf '%s' "$uuid" | /usr/bin/shasum -a 256 | /usr/bin/cut -c1-12
}

detected_hardware_hash() {
  local override="${DOTFILES_HARDWARE_HASH_OVERRIDE:-}"

  if [[ "$DRY_RUN" == true && -n "$override" ]]; then
    printf '%s' "$override"
    return 0
  fi

  machash
}

reset_hardware_profile_record() {
  HARDWARE_PROFILE_RECORD_HASH=""
  HARDWARE_PROFILE_RECORD_ID=""
  HARDWARE_PROFILE_RECORD_NAME=""
  HARDWARE_PROFILE_RECORD_HOSTNAME=""
  HARDWARE_PROFILE_RECORD_INSTALL_MODE=""
  HARDWARE_PROFILE_RECORD_PROFILE_LIST=""
  HARDWARE_PROFILE_RECORD_GIT_USER_NAME=""
  HARDWARE_PROFILE_RECORD_GIT_USER_EMAIL=""
  HARDWARE_PROFILE_RECORD_GIT_SIGNING_KEY=""
  HARDWARE_PROFILE_RECORD_GIT_SIGNING_PROGRAM=""
}

load_hardware_profile_record() {
  local record="$1"
  local fields=()
  local field=""
  local key=""
  local value=""

  reset_hardware_profile_record
  IFS='|' read -r -a fields <<<"$record"

  for field in "${fields[@]}"; do
    key="${field%%=*}"
    value="${field#*=}"

    case "$key" in
    hash) HARDWARE_PROFILE_RECORD_HASH="$value" ;;
    id) HARDWARE_PROFILE_RECORD_ID="$value" ;;
    name) HARDWARE_PROFILE_RECORD_NAME="$value" ;;
    hostname) HARDWARE_PROFILE_RECORD_HOSTNAME="$value" ;;
    install_mode) HARDWARE_PROFILE_RECORD_INSTALL_MODE="$value" ;;
    profile_list) HARDWARE_PROFILE_RECORD_PROFILE_LIST="$value" ;;
    git_user_name) HARDWARE_PROFILE_RECORD_GIT_USER_NAME="$value" ;;
    git_user_email) HARDWARE_PROFILE_RECORD_GIT_USER_EMAIL="$value" ;;
    git_signing_key) HARDWARE_PROFILE_RECORD_GIT_SIGNING_KEY="$value" ;;
    git_signing_program) HARDWARE_PROFILE_RECORD_GIT_SIGNING_PROGRAM="$value" ;;
    esac
  done
}

load_hardware_profile() {
  local hardware_hash="${1:-}"
  local profile_record=""

  HAS_HARDWARE_PROFILE=false
  ACTIVE_HARDWARE_PROFILE_ID=""
  ACTIVE_HARDWARE_PROFILE_NAME=""
  ACTIVE_HARDWARE_PROFILE_HOSTNAME=""
  ACTIVE_HARDWARE_PROFILE_INSTALL_MODE=""
  ACTIVE_HARDWARE_PROFILE_PROFILES=""
  ACTIVE_HARDWARE_PROFILE_GIT_USER_NAME=""
  ACTIVE_HARDWARE_PROFILE_GIT_USER_EMAIL=""
  ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_KEY=""
  ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_PROGRAM=""

  ((${#DOTFILES_HARDWARE_PROFILES[@]} > 0)) || return 0

  for profile_record in "${DOTFILES_HARDWARE_PROFILES[@]}"; do
    load_hardware_profile_record "$profile_record"
    [[ "$HARDWARE_PROFILE_RECORD_HASH" == "$hardware_hash" ]] || continue

    HAS_HARDWARE_PROFILE=true
    ACTIVE_HARDWARE_PROFILE_ID="$HARDWARE_PROFILE_RECORD_ID"
    ACTIVE_HARDWARE_PROFILE_NAME="$HARDWARE_PROFILE_RECORD_NAME"
    ACTIVE_HARDWARE_PROFILE_HOSTNAME="$HARDWARE_PROFILE_RECORD_HOSTNAME"
    ACTIVE_HARDWARE_PROFILE_INSTALL_MODE="$HARDWARE_PROFILE_RECORD_INSTALL_MODE"
    ACTIVE_HARDWARE_PROFILE_PROFILES="$HARDWARE_PROFILE_RECORD_PROFILE_LIST"
    ACTIVE_HARDWARE_PROFILE_GIT_USER_NAME="$HARDWARE_PROFILE_RECORD_GIT_USER_NAME"
    ACTIVE_HARDWARE_PROFILE_GIT_USER_EMAIL="$HARDWARE_PROFILE_RECORD_GIT_USER_EMAIL"
    ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_KEY="$HARDWARE_PROFILE_RECORD_GIT_SIGNING_KEY"
    ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_PROGRAM="$HARDWARE_PROFILE_RECORD_GIT_SIGNING_PROGRAM"
    return
  done
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

at_exit() {
  AT_EXIT+="${AT_EXIT:+$'\n'}"
  AT_EXIT+="${*?}"
  # shellcheck disable=SC2064
  trap "${AT_EXIT}" EXIT
}

parse_args() {
  while (($#)); do
    case "$1" in
    -n | --dry-run)
      DRY_RUN=true
      ;;
    --all-profiles)
      ARG_ALL_PROFILES=true
      ;;
    --core-only)
      ARG_CORE_ONLY=true
      ;;
    --profile)
      shift
      if (($# == 0)); then
        say "Error: --profile requires a comma-separated list" >&2
        exit 1
      fi
      if [[ -z "$1" ]]; then
        say "Error: --profile requires a comma-separated list" >&2
        exit 1
      fi
      ARG_PROFILE_LIST="$1"
      ;;
    --profile=*)
      ARG_PROFILE_LIST="${1#--profile=}"
      if [[ -z "$ARG_PROFILE_LIST" ]]; then
        say "Error: --profile requires a comma-separated list" >&2
        exit 1
      fi
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      say "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    esac
    shift
  done

  if [[ "$ARG_ALL_PROFILES" == true && "$ARG_CORE_ONLY" == true ]]; then
    say "Error: --all-profiles and --core-only cannot be used together" >&2
    exit 1
  fi

  if [[ "$ARG_CORE_ONLY" == true && -n "$ARG_PROFILE_LIST" ]]; then
    say "Error: --core-only and --profile cannot be used together" >&2
    exit 1
  fi
}

profile_label() {
  case "$1" in
  audio) say "audio interface tools" ;;
  dev) say "Docker and development GUI tools" ;;
  formatters) say "formatters and linters" ;;
  languages) say "extra programming language toolchains" ;;
  web3) say "Web3 and blockchain tools" ;;
  cloud) say "cloud and infrastructure tools" ;;
  image) say "image processing libraries" ;;
  productivity) say "productivity extras" ;;
  streaming) say "streaming and recording tools" ;;
  window) say "hotkey/window-management extras" ;;
  *) return 1 ;;
  esac
}

profile_question() {
  case "$1" in
  audio) say "Do you have an audio interface?" ;;
  dev) say "Do you need Docker, Android tools, or developer GUI apps?" ;;
  formatters) say "Do you want extra formatter and linter tools?" ;;
  languages) say "programming language toolchains" ;;
  web3) say "Are you working on Web3 or blockchain projects?" ;;
  cloud) say "Do you work with AWS, Terraform, or cloud infrastructure?" ;;
  image) say "Do you work with image or media processing libraries?" ;;
  productivity) say "Do you want productivity extras like BusyCal?" ;;
  streaming) say "Are you going to stream or record video?" ;;
  window) say "Do you want hotkey and window-management tools?" ;;
  *) return 1 ;;
  esac
}

profile_brewfile() {
  local profile="$1"

  profile_label "$profile" >/dev/null || return 1
  say "$DOTFILES/brewfiles/profiles/$profile"
}

package_matches_filter() {
  local package_name="$1"
  shift

  local wanted=""
  for wanted in "$@"; do
    [[ "$package_name" == "$wanted" ]] && return 0
  done

  return 1
}

print_profile_packages() {
  local profile="$1"
  local indent="${2:-  }"
  shift
  if (($#)); then
    shift
  fi

  local package_filter=("$@")
  local profile_file=""
  local line=""
  local kind=""
  local name=""
  local rest=""
  local description=""
  local printed=false

  profile_file="$(profile_brewfile "$profile")"
  say "${indent}Type   Package                         Notes"
  say "${indent}----   -------                         -----"
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*(brew|cask|tap|mas|vscode)[[:space:]]+\"([^\"]+)\"(.*)$ ]]; then
      kind="${BASH_REMATCH[1]}"
      name="${BASH_REMATCH[2]}"
      rest="${BASH_REMATCH[3]}"
      description=""

      if ((${#package_filter[@]} > 0)) && ! package_matches_filter "$name" "${package_filter[@]}"; then
        continue
      fi

      if [[ "$rest" == *#* ]]; then
        description="${rest#*#}"
        description="${description#"${description%%[![:space:]]*}"}"
      fi

      if [[ -n "$description" ]]; then
        printf '%s%-6s %-31s %s\n' "$indent" "$kind" "$name" "$description"
      else
        printf '%s%-6s %-31s\n' "$indent" "$kind" "$name"
      fi
      printed=true
    fi
  done <"$profile_file"

  if [[ "$printed" != true ]]; then
    say "${indent}(no matching packages)"
  fi
}

ask_profile_package_questions() {
  local profile="$1"
  local profile_file=""
  local line=""
  local name=""
  local rest=""
  local description=""
  local prompt=""

  profile_file="$(profile_brewfile "$profile")"
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*(brew|cask|tap|mas|vscode)[[:space:]]+\"([^\"]+)\"(.*)$ ]]; then
      name="${BASH_REMATCH[2]}"
      rest="${BASH_REMATCH[3]}"
      description=""

      if [[ "$rest" == *#* ]]; then
        description="${rest#*#}"
        description="${description#"${description%%[![:space:]]*}"}"
      fi

      prompt="Install $name"
      if [[ -n "$description" ]]; then
        prompt+=" ($description)"
      fi
      prompt+="?"

      if ask_yes_no "$prompt" "y"; then
        add_profile_package "$profile" "$name"
      fi
    fi
  done <"$profile_file"
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
  local candidate="$1"
  local selected=""

  for selected in "${SELECTED_LANGUAGES[@]}"; do
    [[ "$selected" == "$candidate" ]] && return 0
  done

  return 1
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
  local selected=""

  for selected in "${SELECTED_PROFILE_PACKAGES[@]}"; do
    [[ "$selected" == "$profile:$package_name" ]] && return 0
  done

  return 1
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

  for selected in "${SELECTED_PROFILE_PACKAGES[@]}"; do
    [[ "$selected" == "$profile:"* ]] || continue
    say "${selected#*:}"
  done
}

profile_has_selected_packages() {
  local profile="$1"
  local selected=""

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

normalize_profile() {
  local profile="$1"
  profile="${profile// /}"
  profile="${profile//_/-}"

  case "$profile" in
  audio | audio-interface | focusrite) say "audio" ;;
  dev | dev-tools | development | docker) say "dev" ;;
  formatter | formatters | lint | linters) say "formatters" ;;
  language | languages | runtimes | toolchains) say "languages" ;;
  web3 | blockchain | crypto) say "web3" ;;
  cloud | infra | infrastructure | aws) say "cloud" ;;
  image | images | media-processing) say "image" ;;
  productivity | calendar | busycal) say "productivity" ;;
  stream | streaming | obs) say "streaming" ;;
  window | windows | skhd | hotkeys) say "window" ;;
  *) return 1 ;;
  esac
}

profile_selected() {
  local candidate="$1"
  local selected=""

  for selected in "${SELECTED_PROFILES[@]}"; do
    [[ "$selected" == "$candidate" ]] && return 0
  done

  return 1
}

add_profile() {
  local profile="$1"
  local brewfile=""

  profile_label "$profile" >/dev/null || {
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
  local hardware_hash=""

  [[ -f "$DOTFILES/.installed" ]] && FIRST_RUN=false || FIRST_RUN=true
  hardware_hash="$(detected_hardware_hash 2>/dev/null || true)"
  load_hardware_profile "$hardware_hash"
}

configure_hardware_profile_environment() {
  local i=0
  local managed_identity_count=0
  local name_var=""
  local email_var=""
  local signing_key_var=""
  local signing_program_var=""
  local profile_record=""

  export DOTFILES_HAS_HARDWARE_PROFILE="$HAS_HARDWARE_PROFILE"
  export DOTFILES_HARDWARE_PROFILE_ID="$ACTIVE_HARDWARE_PROFILE_ID"
  export DOTFILES_HARDWARE_PROFILE_NAME="$ACTIVE_HARDWARE_PROFILE_NAME"
  export DOTFILES_HARDWARE_HOSTNAME="$ACTIVE_HARDWARE_PROFILE_HOSTNAME"
  export DOTFILES_GIT_USER_NAME="$ACTIVE_HARDWARE_PROFILE_GIT_USER_NAME"
  export DOTFILES_GIT_USER_EMAIL="$ACTIVE_HARDWARE_PROFILE_GIT_USER_EMAIL"
  export DOTFILES_GIT_SIGNING_KEY="$ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_KEY"
  export DOTFILES_GIT_SIGNING_PROGRAM="$ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_PROGRAM"

  for ((i = 1; i <= ${DOTFILES_MANAGED_GIT_IDENTITY_COUNT:-0}; i++)); do
    unset "DOTFILES_MANAGED_GIT_USER_NAME_$i" "DOTFILES_MANAGED_GIT_USER_EMAIL_$i" "DOTFILES_MANAGED_GIT_SIGNING_KEY_$i" "DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_$i"
  done

  if ((${#DOTFILES_HARDWARE_PROFILES[@]} > 0)); then
    for profile_record in "${DOTFILES_HARDWARE_PROFILES[@]}"; do
      load_hardware_profile_record "$profile_record"
      if [[ -z "$HARDWARE_PROFILE_RECORD_GIT_USER_NAME" && -z "$HARDWARE_PROFILE_RECORD_GIT_USER_EMAIL" && -z "$HARDWARE_PROFILE_RECORD_GIT_SIGNING_KEY" && -z "$HARDWARE_PROFILE_RECORD_GIT_SIGNING_PROGRAM" ]]; then
        continue
      fi

      managed_identity_count=$((managed_identity_count + 1))
      name_var="DOTFILES_MANAGED_GIT_USER_NAME_$managed_identity_count"
      email_var="DOTFILES_MANAGED_GIT_USER_EMAIL_$managed_identity_count"
      signing_key_var="DOTFILES_MANAGED_GIT_SIGNING_KEY_$managed_identity_count"
      signing_program_var="DOTFILES_MANAGED_GIT_SIGNING_PROGRAM_$managed_identity_count"

      printf -v "$name_var" '%s' "$HARDWARE_PROFILE_RECORD_GIT_USER_NAME"
      printf -v "$email_var" '%s' "$HARDWARE_PROFILE_RECORD_GIT_USER_EMAIL"
      printf -v "$signing_key_var" '%s' "$HARDWARE_PROFILE_RECORD_GIT_SIGNING_KEY"
      printf -v "$signing_program_var" '%s' "$HARDWARE_PROFILE_RECORD_GIT_SIGNING_PROGRAM"
      export "${name_var?}" "${email_var?}" "${signing_key_var?}" "${signing_program_var?}"
    done
  fi

  export DOTFILES_MANAGED_GIT_IDENTITY_COUNT="$managed_identity_count"

  if [[ "$HAS_HARDWARE_PROFILE" != true ]]; then
    return
  fi

  unset GIT_USER_NAME GIT_USER_EMAIL GIT_SIGNING_KEY GIT_SIGNING_PROGRAM

  if [[ -n "$ACTIVE_HARDWARE_PROFILE_GIT_USER_NAME" ]]; then
    export GIT_USER_NAME="$ACTIVE_HARDWARE_PROFILE_GIT_USER_NAME"
  fi
  if [[ -n "$ACTIVE_HARDWARE_PROFILE_GIT_USER_EMAIL" ]]; then
    export GIT_USER_EMAIL="$ACTIVE_HARDWARE_PROFILE_GIT_USER_EMAIL"
  fi
  if [[ -n "$ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_KEY" ]]; then
    export GIT_SIGNING_KEY="$ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_KEY"
  fi
  if [[ -n "$ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_PROGRAM" ]]; then
    export GIT_SIGNING_PROGRAM="$ACTIVE_HARDWARE_PROFILE_GIT_SIGNING_PROGRAM"
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

  if [[ "$HAS_HARDWARE_PROFILE" == true ]]; then
    case "$ACTIVE_HARDWARE_PROFILE_INSTALL_MODE" in
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
      if [[ -z "$ACTIVE_HARDWARE_PROFILE_PROFILES" ]]; then
        say "Error: selected install mode for hardware profile '$ACTIVE_HARDWARE_PROFILE_ID' requires explicit profiles" >&2
        exit 1
      fi
      parse_profiles "$ACTIVE_HARDWARE_PROFILE_PROFILES"
      return
      ;;
    *)
      say "Error: invalid install mode for hardware profile '$ACTIVE_HARDWARE_PROFILE_ID': $ACTIVE_HARDWARE_PROFILE_INSTALL_MODE" >&2
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

  if [[ "$ALL_PROFILES" != true ]]; then
    return
  fi

  if ! is_interactive; then
    return
  fi

  section "Cleanup"
  if ask_yes_no "Clean up Homebrew dependencies and cache after install?" "n"; then
    RUN_CLEANUP=true
  fi
}

configure_system_plan() {
  RUN_TOOL_INSTALLERS=true

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

  for tool_dir in "$DOTFILES/tools"/*; do
    [[ -d "$tool_dir" ]] || continue
    tool_name="$(basename "$tool_dir")"
    [[ "$tool_name" == "fish" ]] && continue
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
  if [[ "$HAS_HARDWARE_PROFILE" == true ]]; then
    plan_value "Hardware profile" "registered"
  else
    plan_value "Hardware profile" "unregistered"
  fi
  if [[ "$HAS_HARDWARE_PROFILE" == true ]]; then
    plan_value "Hardware install mode" "$ACTIVE_HARDWARE_PROFILE_INSTALL_MODE"
  fi
  plan_value "First run" "$FIRST_RUN"

  subsection "Brewfiles"
  plan_value "Core Brewfile" "$DOTFILES/brewfiles/core"
  plan_value "Profile Brewfile" "$profile_brewfile"

  subsection "Optional tool groups"
  plan_value "Profile mode" "$(profile_mode)"
  print_selected_profiles

  subsection "Planned actions"
  plan_value "Install Homebrew" "$brew_missing"
  plan_value "Xcode setup" "$RUN_XCODE_SETUP"
  plan_value "Run Homebrew cleanup" "$RUN_CLEANUP"
  plan_value "Tool configs/macOS settings" "$RUN_TOOL_INSTALLERS"
  plan_value "Fish setup" "$RUN_FISH_SETUP"
  plan_value "Projects directory" "$RUN_PROJECTS_SETUP"
  plan_value "Mark install complete" "if no package failures"

  subsection "Tool config/setup scripts"
  list_tool_installers

  if [[ "$DRY_RUN" == true ]]; then
    note "Dry run: exiting before sudo, keychain, Homebrew, mas, cleanup, Stow, chsh, mkdir, or .installed changes."
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
  local language_package_filter=()
  local profile_package_filter=()
  local line=""
  local package_name=""

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

    if [[ "$profile" == "languages" && ${#SELECTED_LANGUAGES[@]} -gt 0 ]]; then
      language_package_filter=()
      for language in "${SELECTED_LANGUAGES[@]}"; do
        while IFS= read -r package; do
          language_package_filter+=("$package")
        done < <(language_packages "$language")
      done

      {
        printf '# %s\n' "$profile_file"
        while IFS= read -r line; do
          if [[ "$line" =~ ^[[:space:]]*(brew|cask|tap|mas|vscode)[[:space:]]+\"([^\"]+)\" ]]; then
            package_name="${BASH_REMATCH[2]}"
            if package_matches_filter "$package_name" "${language_package_filter[@]}"; then
              printf '%s\n' "$line"
            fi
          fi
        done <"$profile_file"
        printf '\n'
      } >>"$output"
    elif profile_has_selected_packages "$profile"; then
      profile_package_filter=()
      while IFS= read -r package; do
        profile_package_filter+=("$package")
      done < <(selected_profile_package_names "$profile")

      {
        printf '# %s\n' "$profile_file"
        while IFS= read -r line; do
          if [[ "$line" =~ ^[[:space:]]*(brew|cask|tap|mas|vscode)[[:space:]]+\"([^\"]+)\" ]]; then
            package_name="${BASH_REMATCH[2]}"
            if package_matches_filter "$package_name" "${profile_package_filter[@]}"; then
              printf '%s\n' "$line"
            fi
          fi
        done <"$profile_file"
        printf '\n'
      } >>"$output"
    else
      {
        printf '# %s\n' "$profile_file"
        cat "$profile_file"
        printf '\n'
      } >>"$output"
    fi
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

trust_homebrew_taps() {
  local brewfile=""
  local line=""
  local package=""
  local owner=""
  local repo=""
  local profile=""
  local tap=""
  local tap_entry_re='^[[:space:]]*tap[[:space:]]+"([^"]+)"'
  local package_entry_re='^[[:space:]]*(brew|cask)[[:space:]]+"([^"]+/[^"]+/[^"]+)"'
  local -a brewfiles=("$DOTFILES/brewfiles/core")
  local -a taps=()
  local -a sorted_taps=()

  command -v brew >/dev/null 2>&1 || return 0

  if [[ "$ALL_PROFILES" == true ]]; then
    for profile in "${PROFILE_ORDER[@]}"; do
      brewfiles+=("$(profile_brewfile "$profile")")
    done
  elif ((${#SELECTED_PROFILES[@]} > 0)); then
    for profile in "${SELECTED_PROFILES[@]}"; do
      brewfiles+=("$(profile_brewfile "$profile")")
    done
  fi

  for brewfile in "${brewfiles[@]}"; do
    [[ -f "$brewfile" ]] || continue

    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ $tap_entry_re ]]; then
        taps+=("${BASH_REMATCH[1]}")
      elif [[ "$line" =~ $package_entry_re ]]; then
        package="${BASH_REMATCH[2]}"
        IFS=/ read -r owner repo _ <<<"$package"
        taps+=("$owner/$repo")
      fi
    done <"$brewfile"
  done

  if ((${#taps[@]} == 0)); then
    return 0
  fi

  while IFS= read -r tap; do
    [[ -n "$tap" ]] || continue
    sorted_taps+=("$tap")
  done < <(printf '%s\n' "${taps[@]}" | sort -u)

  taps=("${sorted_taps[@]}")
  brew trust --tap --quiet "${taps[@]}"
}

setup_sudo_askpass() {
  (
    builtin read -r -s -p "Password: "
    builtin echo "add-generic-password -U -s 'dotfiles' -a '${USER}' -w '${REPLY}'"
  ) | /usr/bin/security -i
  printf "\n"

  at_exit "
printf '\e[0;33mRemoving dotfiles keychain entry ...\e[0m\n'
/usr/bin/security delete-generic-password -s 'dotfiles' -a '${USER}' >/dev/null 2>&1 || true
  "

  SUDO_ASKPASS="$(/usr/bin/mktemp)"
  printf "SUDO_ASKPASS: %s\n" "$SUDO_ASKPASS"

  at_exit "
printf '\e[0;33mDeleting SUDO_ASKPASS script ...\e[0m\n'
/bin/rm -f '${SUDO_ASKPASS}'
  "

  {
    echo "#!/bin/sh"
    echo "/usr/bin/security find-generic-password -s 'dotfiles' -a '${USER}' -w"
  } >"${SUDO_ASKPASS}"

  /bin/chmod +x "${SUDO_ASKPASS}"
  export SUDO_ASKPASS

  if /usr/bin/sudo -A -kv 2>/dev/null; then
    DOTFILES_USE_SUDO_ASKPASS=true
  else
    DOTFILES_USE_SUDO_ASKPASS=false
    printf '\e[0;33mSUDO_ASKPASS helper failed; falling back to interactive sudo.\e[0m\n' 1>&2
    /usr/bin/sudo -v
  fi

  export DOTFILES_USE_SUDO_ASKPASS
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

install_homebrew() {
  if ! command -v brew >/dev/null 2>&1 && [[ ! -x "/opt/homebrew/bin/brew" ]]; then
    say "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    load_homebrew
    say "Updating Homebrew..."
    brew update -q
    brew upgrade -q
  fi
}

install_packages() {
  section "Homebrew packages"
  run_brew_bundle_install "core packages" "$DOTFILES/brewfiles/core"

  if [[ "$ALL_PROFILES" == true ]]; then
    SELECTED_PROFILE_BREWFILE="$(mktemp)"
    at_exit "
/bin/rm -f '${SELECTED_PROFILE_BREWFILE}'
    "
    create_profile_brewfile "$SELECTED_PROFILE_BREWFILE" "${PROFILE_ORDER[@]}"
    run_brew_bundle_install "optional profile packages" "$SELECTED_PROFILE_BREWFILE" "generated all-profiles Brewfile"
  elif ((${#SELECTED_PROFILES[@]} > 0)); then
    SELECTED_PROFILE_BREWFILE="$(mktemp)"
    at_exit "
/bin/rm -f '${SELECTED_PROFILE_BREWFILE}'
    "
    create_profile_brewfile "$SELECTED_PROFILE_BREWFILE" "${SELECTED_PROFILES[@]}"
    run_brew_bundle_install "selected profile packages" "$SELECTED_PROFILE_BREWFILE" "generated selected-profiles Brewfile"
  else
    say "Skipping optional profile Brewfiles."
  fi
}

brew_bundle_failed() {
  ((${#BREW_BUNDLE_FAILURES[@]} > 0))
}

run_brew_bundle_install() {
  local label="$1"
  local brewfile="$2"
  local source_label="${3:-$brewfile}"
  local entry_brewfile=""
  local line=""
  local line_number=0

  entry_brewfile="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    [[ "$line" =~ ^[[:space:]]*(brew|cask|tap|mas|vscode)[[:space:]] ]] || continue

    printf '%s\n' "$line" >"$entry_brewfile"
    if brew bundle install --file "$entry_brewfile"; then
      continue
    fi

    BREW_BUNDLE_FAILURES+=("$label: $source_label:$line_number: $line")
    note "Homebrew bundle failed for $label entry at $source_label:$line_number; continuing with remaining packages."
  done <"$brewfile"

  /bin/rm -f "$entry_brewfile"
}

print_brew_bundle_failures() {
  local failure=""

  brew_bundle_failed || return 0

  section "Homebrew bundle failures"
  say "Some Brewfile entries failed. The rest of the installer continued."
  for failure in "${BREW_BUNDLE_FAILURES[@]}"; do
    say "  - $failure"
  done
  say "Review the Homebrew output above, then rerun ./install.sh after fixing those packages."
}

run_cleanup() {
  if [[ "$RUN_CLEANUP" != true ]]; then
    say "Skipping Homebrew cleanup."
    return
  fi

  section "Homebrew cleanup"
  say "Previewing Brewfile cleanup..."
  bash "$DOTFILES/cleanup.sh" || true
  bash "$DOTFILES/cleanup.sh" --force
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

run_tool_installers() {
  local tool_dir=""
  local tool_name=""

  load_tool_library
  mkdir -p "$HOME/.config"

  for tool_dir in "$DOTFILES/tools"/*; do
    if [[ -d "$tool_dir" ]]; then
      tool_name="$(basename "$tool_dir")"
      [[ "$tool_name" == "fish" ]] && continue
      run_tool "$tool_name"
    fi
  done
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

  cat <<'EOF'
Please restart your terminal to apply changes.

Possible next steps:
-> Configure Raycast
---> Configure HyperKey in Settings -> Advanced
-> Configure 1Password
---> Save Recovery Key
---> Configure 1Password SSH
---> Settings -> Touch ID -> Enable Apple Watch
---> 1Password -> Settings -> Apple Watch
-> Configure CleanShot
-> Install Insta360 Link Controller
-> Configure Clock Screensaver
-> Finish Docker Installation
-> Configure SoundSource and Loopback Licenses
-> Configure BusyCal
-> Configure OBS
-> Add bluetooth permissions to Hammerspoon
EOF
}

main() {
  parse_args "$@"

  if [[ $EUID -eq 0 ]]; then
    say "This script should not be run as root" >&2
    exit 1
  fi

  if [[ "$(uname)" != "Darwin" ]]; then
    say "Invalid OS!" >&2
    exit 1
  fi

  detect_state
  configure_hardware_profile_environment
  configure_install_plan
  configure_cleanup_plan
  configure_system_plan
  print_install_plan

  if [[ "$DRY_RUN" == true ]]; then
    exit 0
  fi

  /usr/bin/caffeinate -dimu -w $$ &
  setup_sudo_askpass
  start_sudo_keepalive
  load_homebrew
  trust_homebrew_taps
  install_homebrew
  load_homebrew
  load_tool_library
  trust_homebrew_taps

  if [[ "$RUN_XCODE_SETUP" == true ]]; then
    section "Xcode"
    brew install mas
    mas install 497799835
    sudo_askpass xcodebuild -license accept
  fi

  install_packages
  run_cleanup
  run_tool_installers
  run_first_run_tasks
  print_brew_bundle_failures

  if brew_bundle_failed; then
    print_next_steps
    exit 1
  fi

  touch "$DOTFILES/.installed"
  print_next_steps
}

main "$@"
