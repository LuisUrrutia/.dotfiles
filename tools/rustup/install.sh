#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin rustup

installed_toolchains="$("$bin_path" toolchain list 2>/dev/null || true)"
stable_installed=false

while IFS= read -r toolchain; do
  toolchain="${toolchain%% *}"
  if [[ "$toolchain" == stable || "$toolchain" == stable-* ]]; then
    stable_installed=true
    break
  fi
done <<<"$installed_toolchains"

if $stable_installed; then
  echo "Rust stable toolchain is already installed"
else
  "$bin_path" toolchain install stable
  echo "Installed stable Rust toolchain"
fi

default_toolchain="$("$bin_path" default 2>/dev/null || true)"
default_toolchain="${default_toolchain%% *}"

if [[ "$default_toolchain" == stable || "$default_toolchain" == stable-* ]]; then
  echo "Rust stable toolchain is already the default"
else
  "$bin_path" default stable
  echo "Set stable as the default Rust toolchain"
fi

rustc_version="$("$bin_path" run stable rustc -vV)"
host_target=""

while IFS= read -r line; do
  if [[ "$line" == host:* ]]; then
    host_target="${line#host: }"
    break
  fi
done <<<"$rustc_version"

if [[ -z "$host_target" ]]; then
  echo "Error: unable to detect Rust host target" >&2
  exit 1
fi

installed_targets="$("$bin_path" target list --installed)"
target_installed=false

while IFS= read -r target; do
  if [[ "$target" == "$host_target" ]]; then
    target_installed=true
    break
  fi
done <<<"$installed_targets"

if $target_installed; then
  echo "Rust target $host_target is already installed"
else
  "$bin_path" target add "$host_target"
  echo "Added $host_target Rust target"
fi

installed_components="$("$bin_path" component list --installed)"

for component in rustfmt clippy; do
  component_installed=false

  while IFS= read -r installed_component; do
    if [[ "$installed_component" == "$component" || "$installed_component" == "$component-"* ]]; then
      component_installed=true
      break
    fi
  done <<<"$installed_components"

  if $component_installed; then
    echo "Rust component $component is already installed"
  else
    "$bin_path" component add "$component"
    echo "Added Rust component $component"
  fi
done
