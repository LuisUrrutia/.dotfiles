#!/usr/bin/env bash

# Profile Brewfiles own package declarations and their public metadata.

array_contains() {
  local needle="$1"
  local item=""
  shift

  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done

  return 1
}

init_profile_order() {
  local profile_file=""

  PROFILE_ORDER=()
  for profile_file in "$DOTFILES/brewfiles/profiles"/*; do
    [[ -f "$profile_file" ]] || continue
    PROFILE_ORDER+=("$(basename "$profile_file")")
  done

  if ((${#PROFILE_ORDER[@]} == 0)); then
    printf 'Error: no profile Brewfiles found in %s\n' "$DOTFILES/brewfiles/profiles" >&2
    return 1
  fi
}

profile_exists() {
  array_contains "$1" "${PROFILE_ORDER[@]}"
}

profile_metadata() {
  local profile="$1"
  local key="$2"
  local profile_file="$DOTFILES/brewfiles/profiles/$profile"
  local value=""

  value="$(sed -n "s/^# ${key}: *//p" "$profile_file" 2>/dev/null | sed -n 1p)"
  if [[ -z "$value" ]]; then
    printf "Error: profile '%s' is missing '# %s:' metadata in %s\n" \
      "$profile" "$key" "$profile_file" >&2
    return 1
  fi

  printf '%s\n' "$value"
}

profile_label() {
  profile_metadata "$1" label
}

profile_question() {
  profile_metadata "$1" question
}

profile_brewfile() {
  local profile="$1"

  profile_exists "$profile" || return 1
  printf '%s\n' "$DOTFILES/brewfiles/profiles/$profile"
}

normalize_profile() {
  local profile="$1"
  local candidate=""
  local aliases=""
  local alias_list=()

  profile="${profile// /}"
  profile="${profile//_/-}"

  for candidate in "${PROFILE_ORDER[@]}"; do
    if [[ "$profile" == "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi

    aliases="$(profile_metadata "$candidate" aliases 2>/dev/null || true)"
    [[ -n "$aliases" ]] || continue
    IFS=', ' read -r -a alias_list <<<"$aliases"
    if ((${#alias_list[@]} > 0)) && array_contains "$profile" "${alias_list[@]}"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}
