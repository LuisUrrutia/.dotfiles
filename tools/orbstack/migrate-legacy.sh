#!/usr/bin/env bash

migrate_retired_docker_plugins() {
  local plugin=""

  for plugin in "$HOME/.docker/cli-plugins"/*; do
    [[ -L "$plugin" && ! -e "$plugin" ]] || continue
    case "$(readlink "$plugin")" in
    /Applications/Docker.app/Contents/Resources/cli-plugins/* | /Applications/Docker.app/Contents/Library/SecretsEngine/*)
      rm "$plugin"
      printf 'Removed retired Docker Desktop plugin link: %s\n' "$plugin"
      ;;
    esac
  done
}
