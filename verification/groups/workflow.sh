#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"
actionlint
tools/bin/config/.local/bin/gha-pins audit .github/workflows
git diff --check
if git grep -nI -E '[[:blank:]]+$' -- .; then
  printf 'Tracked files contain trailing whitespace.\n' >&2
  exit 1
fi
