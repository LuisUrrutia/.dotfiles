#!/usr/bin/env bash
# shellcheck disable=SC2034 # Selection globals are consumed by the Bootstrapper.

apply_install_selection() {
  local mode="$1"
  local profile_list="$2"
  local language_list="$3"
  local package_list="$4"
  local profiles=()
  local languages=()
  local packages=()
  local profile=""
  local language=""
  local selected=""
  local package=""
  local list=""
  local i=0

  case "$mode" in
  all | core)
    [[ -z "$profile_list$language_list$package_list" ]] || return 1
    ;;
  selected)
    [[ -n "$profile_list" ]] || return 1
    ;;
  *) return 1 ;;
  esac

  for list in "$profile_list" "$language_list" "$package_list"; do
    [[ "$list" != ,* && "$list" != *, && "$list" != *,,* ]] || return 1
  done
  if [[ -n "$profile_list" ]]; then
    IFS=, read -r -a profiles <<<"$profile_list"
  fi
  if [[ -n "$language_list" ]]; then
    IFS=, read -r -a languages <<<"$language_list"
  fi
  if [[ -n "$package_list" ]]; then
    IFS=, read -r -a packages <<<"$package_list"
  fi

  for ((i = 0; i < ${#profiles[@]}; i++)); do
    profile="$(normalize_profile "${profiles[$i]}")" || return 1
    profiles[i]="$profile"
  done
  for ((i = 0; i < ${#languages[@]}; i++)); do
    language="${languages[$i]}"
    array_contains languages "${profiles[@]}" || return 1
    array_contains "$language" "${LANGUAGE_ORDER[@]}" || return 1
  done
  for ((i = 0; i < ${#packages[@]}; i++)); do
    selected="${packages[$i]}"
    [[ "$selected" == *:* ]] || return 1
    profile="${selected%%:*}"
    package="${selected#*:}"
    array_contains "$profile" "${profiles[@]}" || return 1
    if [[ "$profile" == languages && ${#languages[@]} -gt 0 ]]; then
      return 1
    fi
    BREWFILE_ENTRY_NAMES=()
    BREWFILE_ENTRY_DESCRIPTIONS=()
    each_brewfile_entry "$(profile_brewfile "$profile")" collect_brewfile_entry
    ((${#BREWFILE_ENTRY_NAMES[@]} > 0)) || return 1
    array_contains "$package" "${BREWFILE_ENTRY_NAMES[@]}" || return 1
  done

  ALL_PROFILES=false
  [[ "$mode" != all ]] || ALL_PROFILES=true
  SELECTED_PROFILES=()
  SELECTED_LANGUAGES=()
  SELECTED_PROFILE_PACKAGES=()
  if ((${#profiles[@]} > 0)); then
    SELECTED_PROFILES=("${profiles[@]}")
  fi
  if ((${#languages[@]} > 0)); then
    SELECTED_LANGUAGES=("${languages[@]}")
  fi
  if ((${#packages[@]} > 0)); then
    SELECTED_PROFILE_PACKAGES=("${packages[@]}")
  fi
}

install_selection_path() {
  local hardware_hash="${DETECTED_HARDWARE_HASH:-unknown}"

  if [[ ! "$hardware_hash" =~ ^[a-f0-9]{12}$ ]]; then
    hardware_hash=unknown
  fi
  printf '%s/dotfiles/install-selection/%s\n' \
    "${XDG_STATE_HOME:-$HOME/.local/state}" "$hardware_hash"
}

save_install_selection() {
  local selection_file=""
  local temporary=""
  local IFS=,

  [[ "$DRY_RUN" != true ]] && is_interactive || return 0
  selection_file="$(install_selection_path)"
  mkdir -p "$(dirname "$selection_file")"
  temporary="$(mktemp "$selection_file.XXXXXX")"
  if ! printf 'version=1\nmode=%s\nprofiles=%s\nlanguages=%s\npackages=%s\n' \
    "$(profile_mode)" "${SELECTED_PROFILES[*]-}" \
    "${SELECTED_LANGUAGES[*]-}" "${SELECTED_PROFILE_PACKAGES[*]-}" >"$temporary"; then
    rm -f "$temporary"
    return 1
  fi
  if ! mv -f "$temporary" "$selection_file"; then
    rm -f "$temporary"
    return 1
  fi
  note "Tool selection saved for recovery: $selection_file"
}

load_install_selection() {
  local selection_file="$1"
  local key=""
  local value=""
  local mode=""
  local profile_list=""
  local language_list=""
  local package_list=""
  local line=0

  [[ -f "$selection_file" && ! -L "$selection_file" ]] || return 1
  # Recovery state is data, never a shell script to source.
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    line=$((line + 1))
    case "$line:$key" in
    1:version) [[ "$value" == 1 ]] || return 1 ;;
    2:mode) mode="$value" ;;
    3:profiles) profile_list="$value" ;;
    4:languages) language_list="$value" ;;
    5:packages) package_list="$value" ;;
    *) return 1 ;;
    esac
  done <"$selection_file"
  [[ "$line" -eq 5 ]] || return 1
  apply_install_selection "$mode" "$profile_list" "$language_list" "$package_list"
}

offer_saved_install_selection() {
  local selection_file=""

  [[ "$DRY_RUN" != true ]] && is_interactive || return 1
  selection_file="$(install_selection_path)"
  [[ -e "$selection_file" || -L "$selection_file" ]] || return 1
  if ! load_install_selection "$selection_file"; then
    note "Saved tool selection is invalid or includes unavailable tools; choose a new selection."
    return 1
  fi

  section "Interrupted installation"
  print_selected_profiles
  if ask_yes_no "Reuse the saved tool selection from the interrupted installation?" y; then
    return 0
  fi
  ALL_PROFILES=false
  SELECTED_PROFILES=()
  SELECTED_LANGUAGES=()
  SELECTED_PROFILE_PACKAGES=()
  return 1
}

clear_install_selection() {
  [[ "$DRY_RUN" != true ]] && is_interactive || return 0
  rm -f "$(install_selection_path)"
}

offer_machine_config() {
  local machine_file=""
  local IFS=,

  [[ "$DRY_RUN" != true ]] && is_interactive || return 0
  if [[ ! "$DETECTED_HARDWARE_HASH" =~ ^[a-f0-9]{12}$ ]]; then
    note "Cannot create a Machine Config without a valid hardware hash."
    return 0
  fi
  machine_file="$MACHINES_DIR/$DETECTED_HARDWARE_HASH.sh"
  if [[ -e "$machine_file" || -L "$machine_file" ]]; then
    note "Machine Config already exists; leaving it unchanged: $machine_file"
    return 0
  fi

  section "Machine Config"
  say "Save this tool selection in $machine_file for future installations."
  if ! ask_yes_no "Create a Machine Config for this hardware using the installed tool selection?" n; then
    return 0
  fi

  mkdir -p "$MACHINES_DIR"
  (
    set -o noclobber
    printf '# shellcheck shell=bash disable=SC2034\n\nMACHINE_ID=%q\nMACHINE_NAME=%q\nMACHINE_INSTALL_MODE=%q\nMACHINE_PROFILES=%q\nMACHINE_LANGUAGES=%q\nMACHINE_PROFILE_PACKAGES=%q\nMACHINE_XCODE_SETUP=false\n' \
      "mac-$DETECTED_HARDWARE_HASH" "Mac $DETECTED_HARDWARE_HASH" \
      "$(profile_mode)" "${SELECTED_PROFILES[*]-}" \
      "${SELECTED_LANGUAGES[*]-}" "${SELECTED_PROFILE_PACKAGES[*]-}" >"$machine_file"
  )
  say "Created $machine_file. Review its labels and commit it to keep the selection versioned."
}
