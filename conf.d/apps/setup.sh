#!/usr/bin/env bash
set -euo pipefail

cursor=/Applications/Cursor.app/Contents/Resources/app/bin/cursor
[[ -x "$cursor" ]] || { echo 'Cursor extension installer is missing' >&2; exit 1; }
"$cursor" --install-extension catppuccin.catppuccin-vsc
"$cursor" --install-extension vscodevim.vim
