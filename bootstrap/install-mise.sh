#!/usr/bin/env bash
set -euo pipefail

version=2026.10.7
case "$(uname -s)/$(uname -m)" in
Darwin/arm64)
  platform=macos-arm64
  checksum=5841e5ab5009b4c4dd2b641ddbfc6777cc1b9c9c0ffd375001e294540e9e9cc8
  ;;
Darwin/x86_64)
  platform=macos-x64
  checksum=809b60fb1f7f5b8794db9c2ac78e5dc40df2e2a2e91d75e7dc97da1ecdc2755e
  ;;
*)
  echo 'This installer currently supports macOS. Linux enrollment is not implemented.' >&2
  exit 1
  ;;
esac

destination="${1:-$HOME/.local/bin/mise}"
parent="$(dirname "$destination")"
while [[ "$parent" != / && "$parent" != . ]]; do
  if [[ -L "$parent" || ( -e "$parent" && ! -d "$parent" ) ]]; then
    echo "Refusing redirected mise directory: $parent" >&2
    exit 1
  fi
  parent="$(dirname "$parent")"
done
if [[ -L "$destination" || ( -e "$destination" && ! -f "$destination" ) ]]; then
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
  if ((BASH_REMATCH[1] > 2026 || (BASH_REMATCH[1] == 2026 && BASH_REMATCH[2] > 10) || (BASH_REMATCH[1] == 2026 && BASH_REMATCH[2] == 10 && BASH_REMATCH[3] >= 7))); then
    printf '%s\n' "$installed_version"
    exit 0
  fi
fi
scratch="$(mktemp -d)"
replacement=
trap 'rm -rf "$scratch"; if [[ -n "$replacement" ]]; then rm -f "$replacement"; fi' EXIT
archive="mise-v$version-$platform.tar.gz"
curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 180 \
  "https://github.com/jdx/mise/releases/download/v$version/$archive" -o "$scratch/$archive"
printf '%s  %s\n' "$checksum" "$scratch/$archive" | shasum -a 256 --check --status
/usr/bin/tar -xzf "$scratch/$archive" -C "$scratch" mise/bin/mise
mkdir -p "$(dirname "$destination")"
replacement="$(mktemp "${destination}.pending.XXXXXXXX")"
/usr/bin/install -m 755 "$scratch/mise/bin/mise" "$replacement"
if [[ -f "$destination" ]]; then
  backup="$(mktemp -d "${destination}.previous.XXXXXXXX")"
  cp -p "$destination" "$backup/mise"
  printf 'Preserved previous mise at %s/mise\n' "$backup"
fi
mv -f "$replacement" "$destination"
replacement=
"$destination" --version
