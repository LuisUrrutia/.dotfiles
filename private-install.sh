#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

PRIVATE_REPO="git@github.com:LuisUrrutia/private.git"
PRIVATE_DIR="$DOTFILES/private"

ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" || {
  echo "Error: GitHub SSH authentication failed."
  echo "Please ensure your SSH key is properly set up with GitHub."
  exit 1
}

if [[ ! -d "$PRIVATE_DIR" ]]; then
  echo "Cloning private repository..."
  git clone "$PRIVATE_REPO" "$PRIVATE_DIR"
else
  echo "Private repository already exists. Pulling latest changes..."
  git -C "$PRIVATE_DIR" pull
fi

if ! command -v stow &>/dev/null; then
  echo "Error: stow is not installed."
  echo "Please install stow first."
  exit 1
fi

echo "Running private install script..."
if [[ -f "$PRIVATE_DIR/install.sh" ]]; then
  "$PRIVATE_DIR/install.sh"
else
  echo "Error: install.sh script not found in the private repository."
  exit 1
fi

echo "Private installation completed!"
