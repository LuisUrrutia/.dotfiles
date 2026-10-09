#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'OrbStack migration test: %s\n' "$*" >&2
  exit 1
}

export HOME="$TMP_DIR/home"
source "$ROOT_DIR/tools/orbstack/migrate-legacy.sh"
migrate_retired_docker_plugins

plugins="$HOME/.docker/cli-plugins"
mkdir -p "$plugins"
printf 'custom plugin\n' >"$plugins/docker-custom"
ln -s /Applications/Docker.app/Contents/Resources/cli-plugins/retired-fixture "$plugins/docker-retired"
ln -s /Applications/Docker.app/Contents/Library/SecretsEngine/retired-fixture "$plugins/docker-pass"
ln -s "$TMP_DIR/foreign-plugin" "$plugins/docker-foreign"
ln -s docker-custom "$plugins/docker-working"
mkdir -p "$HOME/.docker/volumes"
printf 'volume data\n' >"$HOME/.docker/volumes/fixture"

migrate_retired_docker_plugins
migrate_retired_docker_plugins

[[ ! -L "$plugins/docker-retired" && ! -L "$plugins/docker-pass" ]] || fail "retired links survived"
[[ -L "$plugins/docker-foreign" ]] || fail "foreign link was removed"
[[ -L "$plugins/docker-working" && -e "$plugins/docker-working" ]] || fail "working link was removed"
[[ "$(cat "$plugins/docker-custom")" == 'custom plugin' ]] || fail "custom plugin changed"
[[ "$(cat "$HOME/.docker/volumes/fixture")" == 'volume data' ]] || fail "container data changed"

printf 'OrbStack migration test: passed\n'
