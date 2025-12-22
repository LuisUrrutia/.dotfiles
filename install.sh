#!/usr/bin/env bash

# Prevent running as root
if [[ $EUID -eq 0 ]]; then
  echo "This script should not be run as root"
  exit 1
fi

# Only runs in macOS
if [ "$(uname)" != "Darwin" ]; then
  echo "Invalid OS!"
  exit 1
fi

export DOTFILES="${HOME}/.dotfiles"

# Prevent system sleep.
/usr/bin/caffeinate -dimu -w $$ &

# Add exit handlers.
at_exit() {
  AT_EXIT+="${AT_EXIT:+$'\n'}"
  AT_EXIT+="${*?}"
  # shellcheck disable=SC2064
  trap "${AT_EXIT}" EXIT
}

# Ask for superuser password, and temporarily add it to the Keychain.
(
  builtin read -r -s -p "Password: "
  builtin echo "add-generic-password -U -s 'dotfiles' -a '${USER}' -w '${REPLY}'"
) | /usr/bin/security -i
printf "\n"

# Create SUDO_ASKPASS script (scripts that output the password for sudo)
SUDO_ASKPASS="$(/usr/bin/mktemp)"
printf "SUDO_ASKPASS: $SUDO_ASKPASS\n"

at_exit "
	printf '\e[0;31mDeleting SUDO_ASKPASS script …\e[0m\n'
	/bin/rm -f '${SUDO_ASKPASS}'
"

{
  echo "#!/bin/sh"
  echo "/usr/bin/security find-generic-password -s 'dotfiles' -a '${USER}' -w"
} >"${SUDO_ASKPASS}"

/bin/chmod +x "${SUDO_ASKPASS}"

export SUDO_ASKPASS

if ! /usr/bin/sudo -A -kv 2>/dev/null; then
  printf '\e[0;31mIncorrect password.\e[0m\n' 1>&2
  exit 1
fi

# Check if brew is installed, otherwise install it
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Updating Homebrew..."
  brew update -q
  brew upgrade -q
fi

# Load homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

[[ "$USER" == "luisurrutia" ]] && IS_OWNER=true || IS_OWNER=false

if $IS_OWNER; then
  FULL_INSTALL=true
else
  echo "These dotfiles contain personal configurations tailored for the owner."
  echo "A generic version is available that excludes some really personal settings."
  read -r -p "Install the full version anyway? [Y/n] " response
  case "$response" in
    [nN][oO]|[nN])
      FULL_INSTALL=false
      ;;
    *)
      FULL_INSTALL=true
      ;;
  esac
fi


echo "Installing packages from Brewfile..."
brew bundle install --file "$DOTFILES/brewfiles/core"
$FULL_INSTALL && brew bundle install --file "$DOTFILES/brewfiles/personal"
brew cleanup

source "$DOTFILES/tools/lib.sh"

# Core tools (always installed)
CORE_TOOLS="xcode fzf git wget vim tmux starship bat btop linearmouse cspell kitty hammerspoon macos dockutil"

# Full install tools (owner or user opted-in)
FULL_TOOLS="fnm uv rustup luarocks openjdk ice yabai claude skhd"

for tool in $CORE_TOOLS; do
  run_tool "$tool"
done

if $FULL_INSTALL; then
  for tool in $FULL_TOOLS; do
    run_tool "$tool"
  done
fi

# Stow adopt could override some files, so we need to restore them
git -C "$DOTFILES" checkout .

# Create Projects folder
mkdir -p ~/Projects

# Configure fish shell (last, as it changes the default shell)
run_tool "fish"

echo "Installation complete!"
echo "Please restart your terminal to apply changes."
echo ""
echo "Possible next steps:"
echo "-> Configure Raycast"
echo "---> Configure HyperKey in Settings -> Advanced"
echo "-> Configure 1Password"
echo "---> Save Recovery Key"
echo "---> Configure 1Password SSH"
echo "---> Settings -> Touch ID -> Enable Apple Watch"
echo "---> 1Password -> Settings -> Apple Watch"
echo "-> Configure CleanShot"
echo "-> Install Insta360 Link Controller"
echo "-> Configure Clock Screensaver"
echo "-> Finish Docker Installation"
echo "-> Configure SoundSource and Loopback Licenses"
echo "-> Configure BusyCal"
echo "-> Configure OBS"
echo "-> Add bluetooth permissions to Hammerspoon"
