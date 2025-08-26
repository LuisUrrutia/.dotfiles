#!/usr/bin/env bash

# Only runs in macOS
if [ "$(uname)" != "Darwin" ]; then
	echo "Invalid OS!"
	exit 1
fi

STOW_FOLDERS="fish,wget,git,vim,tmux,starship,bat,btop,linearmouse,cspell"
DOTFILES="${HOME}/.dotfiles"

CWD="$(pwd)"

sudo -v
while true; do
	sudo -n true
	sleep 30
	kill -0 "$$" || exit
done 2>/dev/null &

# Check if brew is installed, otherwise install it
which -s brew
if [[ $? != 0 ]]; then
	NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
	brew update -q
	brew upgrade -q
fi

# Load homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"
HOMEBREW_PREFIX=$(brew --prefix)

brew bundle install
brew cleanup

uv python install
uv tool install pre-commit --with pre-commit-uv

[ ! -L "${HOMEBREW_PREFIX}/bin/sha256sum" ] && ln -s "${HOMEBREW_PREFIX}/bin/gsha256sum" "${HOMEBREW_PREFIX}/bin/sha256sum"

$HOMEBREW_PREFIX/opt/fzf/install --all --no-bash --no-zsh --no-fish --no-update-rc --key-bindings --completion

# Configure ZSH and config files
# rm $HOME/.zshrc $HOME/.zshenv $HOME/.zlogin

# Remove fish config if it exists because we will use stow to add stuff
rm -rf $HOME/.config/fish/

for folder in $(echo $STOW_FOLDERS | sed "s/,/ /g"); do
	echo "stow $folder"
	stow -D $folder
	stow $folder -t $HOME
done

bat cache --build

defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "$DOTFILES/iterm"
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

# Create Projects folder
mkdir -p ~/Projects

# Set MacOS props
sh macos.sh

# Restore Cursor settings
sh cursor.sh

# Set zsh if not already default shell
# if [[ "$SHELL" != "/bin/zsh" ]]; then
# 	chsh -s /bin/zsh
# fi

# Add fish to shells and set it as default
sudo sh -c 'echo /opt/homebrew/bin/fish >> /etc/shells'
chsh -s /opt/homebrew/bin/fish

echo "Installation complete!"
echo "Please restart your terminal to apply changes."
echo ""
echo "Possible next steps:"
echo "-> Configure Raycast"
echo "-> Save Recovery Key in 1Password"
echo "-> Configure 1Password SSH"
echo "-> Settings -> Touch ID -> Enable Apple Watch"
echo "-> 1Password -> Settings -> Apple Watch"
echo "-> Configure CleanShot"
echo "-> Install Insta360 Link Controller"
echo "-> Configure Clock Screensaver"
echo "-> Configure Hyperkey"
echo "-> Finish Docker Installation"
echo "-> Configure SoundSource and Loopback Licenses"
echo "-> Configure Fantastical"
echo "-> Configure OBS"
