#!/usr/bin/env bash
set -euo pipefail

directory="$HOME/.config/fish/completions"
mkdir -p "$directory"
uv generate-shell-completion fish >"$directory/uv.fish.tmp"
mv "$directory/uv.fish.tmp" "$directory/uv.fish"
uvx --generate-shell-completion fish >"$directory/uvx.fish.tmp"
mv "$directory/uvx.fish.tmp" "$directory/uvx.fish"
