#!/usr/bin/env bash
set -euo pipefail

"/Applications/Ghostty.app/Contents/MacOS/ghostty" +validate-config --config-file="$HOME/.config/ghostty/config.ghostty"
