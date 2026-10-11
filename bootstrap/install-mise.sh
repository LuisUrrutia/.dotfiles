#!/usr/bin/env bash
set -euo pipefail

destination="${1:-$HOME/.local/bin/mise}"
parent="$(dirname "$destination")"
while [[ "$parent" != / && "$parent" != . ]]; do
  if [[ -L "$parent" || (-e "$parent" && ! -d "$parent") ]]; then
    echo "Refusing redirected mise directory: $parent" >&2
    exit 1
  fi
  parent="$(dirname "$parent")"
done
if [[ -L "$destination" || (-e "$destination" && ! -f "$destination") ]]; then
  echo "Refusing unowned mise destination: $destination" >&2
  exit 1
fi
if [[ -f "$destination" && ! -x "$destination" ]]; then
  echo "Refusing a non-executable file at the mise destination: $destination" >&2
  exit 1
fi
if [[ -x "$destination" ]]; then
  installed_version="$("$destination" --version)"
  if [[ ! "$installed_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    echo "The existing destination does not identify as mise: $destination" >&2
    exit 1
  fi
fi
scratch="$(mktemp -d)"
replacement=
trap 'rm -rf "$scratch"; if [[ -n "$replacement" ]]; then rm -f "$replacement"; fi' EXIT
if [[ -f "$destination" ]]; then
  cp -p "$destination" "$scratch/mise"
fi
curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 180 \
  https://mise.run -o "$scratch/install.sh"
# Upstream selects the platform and newest eligible release, and verifies SHA-256.
unset MISE_VERSION
MISE_INSTALL_PATH="$scratch/mise" MISE_INSTALL_HELP=0 \
  MISE_SELF_UPDATE_MINIMUM_RELEASE_AGE=0s \
  /bin/sh "$scratch/install.sh" </dev/null
if [[ -f "$destination" ]] && cmp -s "$scratch/mise" "$destination"; then
  "$destination" --version
  exit 0
fi
mkdir -p "$(dirname "$destination")"
replacement="$(mktemp "${destination}.pending.XXXXXXXX")"
install -m 755 "$scratch/mise" "$replacement"
if [[ -f "$destination" ]]; then
  backup="$(mktemp -d "${destination}.previous.XXXXXXXX")"
  cp -p "$destination" "$backup/mise"
  printf 'Preserved previous mise at %s/mise\n' "$backup"
fi
mv -f "$replacement" "$destination"
replacement=
"$destination" --version
