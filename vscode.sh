#!/usr/bin/env bash

# Install visual studio code extensions
extensions=(
    "ms-vsliveshare.vsliveshare"
    "christian-kohler.npm-intellisense"
    "eamodio.gitlens"
    "vscodevim.vim"
    "ms-python.python"
    "dbaeumer.vscode-eslint"
    "ms-azuretools.vscode-docker"
    "PKief.material-icon-theme"
    "golang.Go"
    "christian-kohler.path-intellisense"
    "EditorConfig.EditorConfig"
    "dotenv.dotenv-vscode"
    "GitHub.copilot"
    "alefragnani.Bookmarks"
    "HashiCorp.terraform"
    "Equinusocio.vsc-material-theme"
    "bradlc.vscode-tailwindcss"
    "ms-vscode.hexeditor"
    "bierner.github-markdown-preview"
    "JuanBlanco.solidity"
    "kamikillerto.vscode-colorize"
    "wayou.vscode-todo-highlight"
    "gruntfuggly.todo-tree"
    "usernamehw.errorlens"
    "steoates.autoimport"
    "aaron-bond.better-comments"
    "aleonardssh.vscord"
    "googlecloudtools.cloudcode"
    "ms-vscode-remote.remote-containers"
    "graphql.vscode-graphql"
    "graphql.vscode-graphql-syntax"
    "graphql.vscode-graphql-execution"
    "davidanson.vscode-markdownlint"
    "ms-ossdata.vscode-postgresql"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-ssh-edit"
    "sonarsource.sonarlint-vscode"
    "redhat.vscode-xml"
    "redhat.vscode-yaml"
)

for str in ${extensions[@]}; do
  code --install-extension $str
done