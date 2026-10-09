#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"
source "$DOTFILES/tools/orbstack/migrate-legacy.sh"

require_app OrbStack

migrate_retired_docker_plugins
