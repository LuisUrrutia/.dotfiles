#!/usr/bin/env bash
set -euo pipefail

npm config set min-release-age 3 --location=user
directory="$HOME/.config/fish/completions"
mkdir -p "$directory"
SHELL=fish bun completions >"$directory/bun.fish.tmp"
mv "$directory/bun.fish.tmp" "$directory/bun.fish"
