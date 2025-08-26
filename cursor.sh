#!/usr/bin/env bash

# Temporary solution to backup and restore cursor settings
# because cursor doesn't cross device sync
# https://github.com/getcursor/cursor/issues/876

DOTFILES="${HOME}/.dotfiles"
SETTINGS_PATH="$HOME/Library/Application Support/Cursor/User"
SETTINGS_FILE="$SETTINGS_PATH/settings.json"

# if settings.json exists and is not a symlink, remove it
if [ -f "$SETTINGS_FILE" ] && [ ! -L "$SETTINGS_FILE" ]; then
	rm -f "$SETTINGS_FILE"
else
	mkdir -p "$SETTINGS_PATH"
fi

# create symlink
ln -s "$DOTFILES/cursor/settings.json" "$SETTINGS_FILE"