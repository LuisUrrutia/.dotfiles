#!/usr/bin/env bash

# The Tool Catalog is the only discovery path used by the public command and
# the Bootstrapper. A Tool Installer is catalogued only when its directory and
# script are real, executable paths inside this repository.

list_tools() {
  local tool_dir=""
  local installer=""

  for tool_dir in "$DOTFILES/tools"/*; do
    [[ -d "$tool_dir" && ! -L "$tool_dir" ]] || continue
    installer="$tool_dir/install.sh"
    [[ -f "$installer" && -x "$installer" && ! -L "$installer" ]] || continue
    basename "$tool_dir"
  done
}

tool_exists() {
  local requested="$1"
  local tool=""

  while IFS= read -r tool; do
    [[ "$tool" == "$requested" ]] && return 0
  done < <(list_tools)
  return 1
}

run_tool() {
  local tool="$1"
  local script="$DOTFILES/tools/$tool/install.sh"

  if ! tool_exists "$tool"; then
    printf 'Warning: Tool Installer is unavailable or unsafe, skipping: %s\n' "$tool" >&2
    return 0
  fi

  printf 'Configuring %s...\n' "$tool"
  /bin/bash "$script"
}
