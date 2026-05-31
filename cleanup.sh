#!/usr/bin/env bash

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
BREWFILES_DIR="$DOTFILES/brewfiles"
PROFILE_BREWFILES_DIR="$BREWFILES_DIR/profiles"
MERGED_BREWFILE="$(mktemp)"
BREW_BUNDLE_CLEANUP_ARGS=()
BREWFILES=()

case "${1:-}" in
--force)
  BREW_BUNDLE_CLEANUP_ARGS+=(--force)
  ;;
"")
  ;;
*)
  echo "Usage: $0 [--force]" >&2
  exit 1
  ;;
esac

cleanup() {
  rm -f "$MERGED_BREWFILE"
}
trap cleanup EXIT

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is not installed" >&2
  exit 1
fi

if [[ ! -d "$BREWFILES_DIR" ]]; then
  echo "Error: missing brewfiles directory: $BREWFILES_DIR" >&2
  exit 1
fi

BREWFILES+=("$BREWFILES_DIR/core")

if [[ -d "$PROFILE_BREWFILES_DIR" ]]; then
  for brewfile in "$PROFILE_BREWFILES_DIR"/*; do
    [[ -f "$brewfile" ]] || continue
    BREWFILES+=("$brewfile")
  done
fi

for brewfile in "${BREWFILES[@]}"; do
  [[ -f "$brewfile" ]] || continue
  {
    printf '# %s\n' "$brewfile"
    cat "$brewfile"
    printf '\n'
  } >>"$MERGED_BREWFILE"
done

if [[ ! -s "$MERGED_BREWFILE" ]]; then
  echo "Error: no Brewfiles found in $BREWFILES_DIR" >&2
  exit 1
fi

brew bundle cleanup --file="$MERGED_BREWFILE" "${BREW_BUNDLE_CLEANUP_ARGS[@]}"
