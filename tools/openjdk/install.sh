#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_opt openjdk

src="${opt_path}/libexec/openjdk.jdk"
dest="/Library/Java/JavaVirtualMachines/openjdk.jdk"

# Check if already correctly linked
if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
  echo "openjdk already linked at $dest"
  exit 0
fi

# Create parent directory if needed
sudo mkdir -p "$(dirname "$dest")"

sudo ln -sfn "$src" "$dest"
echo "Created symlink: $dest -> $src"
