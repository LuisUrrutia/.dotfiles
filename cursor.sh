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
elif
    mkdir -p "$SETTINGS_PATH"
fi

# create symlink
ln -s "$DOTFILES/cursor/settings.json" "$SETTINGS_FILE"

# install extensions
cursor --install-extension aaron-bond.better-comments
cursor --install-extension alefragnani.bookmarks
cursor --install-extension anysphere.pyright
cursor --install-extension astro-build.astro-vscode
cursor --install-extension asvetliakov.vscode-neovim
cursor --install-extension bradlc.vscode-tailwindcss
cursor --install-extension catppuccin.catppuccin-vsc
cursor --install-extension davidanson.vscode-markdownlint
cursor --install-extension dbaeumer.vscode-eslint
cursor --install-extension donjayamanne.githistory
cursor --install-extension eamodio.gitlens
cursor --install-extension editorconfig.editorconfig
cursor --install-extension esbenp.prettier-vscode
cursor --install-extension foxundermoon.shell-format
cursor --install-extension github.vscode-github-actions
cursor --install-extension github.vscode-pull-request-github
cursor --install-extension golang.go
cursor --install-extension james-yu.latex-workshop
cursor --install-extension juanblanco.solidity
cursor --install-extension ms-azuretools.vscode-docker
cursor --install-extension ms-python.debugpy
cursor --install-extension ms-python.python
cursor --install-extension ms-python.vscode-pylance
cursor --install-extension ms-vscode.makefile-tools
cursor --install-extension ms-vsliveshare.vsliveshare
cursor --install-extension orta.vscode-jest
cursor --install-extension oxc.oxc-vscode
cursor --install-extension redhat.vscode-xml
cursor --install-extension rust-lang.rust-analyzer
cursor --install-extension streetsidesoftware.code-spell-checker
cursor --install-extension svelte.svelte-vscode
cursor --install-extension tamasfe.even-better-toml
cursor --install-extension thang-nm.catppuccin-perfect-icons
cursor --install-extension usernamehw.errorlens
cursor --install-extension vadimcn.vscode-lldb
cursor --install-extension wix.vscode-import-cost
cursor --install-extension yoavbls.pretty-ts-errors
cursor --install-extension yzhang.markdown-all-in-one
