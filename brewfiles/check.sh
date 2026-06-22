#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$SCRIPT_DIR/.." && pwd)"
BREWFILES=("$DOTFILES/brewfiles/core")
ENTRY_RE='^[[:space:]]*(tap|brew|cask)[[:space:]]+"([^"]+)"(.*)$'
TRUST_RE='(^|[[:space:],])trusted:[[:space:]]*true([[:space:],#]|$)'

if [[ -d "$DOTFILES/brewfiles/profiles" ]]; then
  for brewfile in "$DOTFILES/brewfiles/profiles"/*; do
    [[ -f "$brewfile" ]] || continue
    BREWFILES+=("$brewfile")
  done
fi

check_syntax() {
  local brewfile="$1"

  ruby -c "$brewfile" >/dev/null
}

requires_trust() {
  local kind="$1"
  local name="$2"
  local owner=""
  local repo=""
  local package=""
  local extra=""

  case "$kind" in
  tap)
    [[ "$name" == homebrew/* ]] && return 1
    return 0
    ;;
  brew | cask)
    IFS=/ read -r owner repo package extra <<<"$name"
    [[ -n "$owner" && -n "$repo" && -n "$package" && -z "$extra" ]] || return 1
    [[ "$owner" == homebrew ]] && return 1
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

check_trust_metadata() {
  local brewfile="$1"
  local line=""
  local kind=""
  local name=""
  local options=""
  local rest=""
  local line_number=0
  local failed=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    if [[ "$line" =~ $ENTRY_RE ]]; then
      kind="${BASH_REMATCH[1]}"
      name="${BASH_REMATCH[2]}"
      rest="${BASH_REMATCH[3]}"
      options="${rest%%#*}"

      if requires_trust "$kind" "$name" && [[ ! "$options" =~ $TRUST_RE ]]; then
        printf '%s:%s: %s "%s" must include trusted: true\n' "$brewfile" "$line_number" "$kind" "$name" >&2
        failed=true
      fi
    fi
  done <"$brewfile"

  [[ "$failed" != true ]]
}

for brewfile in "${BREWFILES[@]}"; do
  check_syntax "$brewfile"
  check_trust_metadata "$brewfile"
done
