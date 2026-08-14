#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"
actionlint
tools/bin/config/.local/bin/gha-pins audit .github/workflows
git diff --check
