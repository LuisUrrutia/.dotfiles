#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"
luacheck tools/hammerspoon
stylua --check tools/vim/config/.config/nvim
/bin/bash tools/vim/tests/config.sh
/bin/bash tools/hammerspoon/tests/run.sh
