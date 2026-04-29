#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

DOTFILES_TEST_ROOT="$ROOT_DIR" lua "$ROOT_DIR/tools/hammerspoon/tests/unit.lua"
