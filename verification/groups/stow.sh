#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"

temporary_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-stow.XXXXXX")"
trap 'rm -rf "$temporary_home"' EXIT

for tool_dir in tools/*; do
  [[ -d "$tool_dir/config" ]] || continue
  stow --no-folding --restow -d "$tool_dir" -t "$temporary_home" config
done
