#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"
luacheck tools/hammerspoon
/bin/bash tools/hammerspoon/tests/run.sh
