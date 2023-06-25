#!/usr/bin/env bash

# Install visual studio code extensions
extensions=(
    "equinusocio.vsc-community-material-theme"
    "PKief.material-icon-theme"
    "esbenp.prettier-vscode"
    "ms-vsliveshare.vsliveshare"
    "eamodio.gitlens"
    "vscodevim.vim"
    "ms-python.python"
    "dbaeumer.vscode-eslint"
    "ms-azuretools.vscode-docker"
    "golang.Go"
    "christian-kohler.path-intellisense"
    "EditorConfig.EditorConfig"
    "dotenv.dotenv-vscode"
    "github.copilot-nightly"
    "github.copilot-chat"
    "alefragnani.Bookmarks"
    "gruntfuggly.todo-tree"
    "usernamehw.errorlens"
    "aaron-bond.better-comments"
    "sonarsource.sonarlint-vscode"
)

for str in ${extensions[@]}; do
  code-insiders --install-extension $str
done