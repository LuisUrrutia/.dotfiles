#!/usr/bin/env bash

# Only runs in macOS
if [ "$(uname)" != "Darwin" ]; then
	echo "Invalid OS!"
	exit 1
fi

STOW_FOLDERS="fish,wget,git,vim,tmux,starship,bat,btop,linearmouse,cspell,atuin"
DOTFILES="${HOME}/.dotfiles"

sudo -v
while true; do
	sudo -n true
	sleep 20
	kill -0 "$$" || exit
done 2>/dev/null &

# Check if brew is installed, otherwise install it
which -s brew
if [[ $? != 0 ]]; then
	echo "Installing Homebrew..."
	NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
	echo "Updating Homebrew..."
	brew update -q
	brew upgrade -q
fi

# Load homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

echo "Installing packages from Brewfile..."
brew bundle install --file $DOTFILES/Brewfile
brew cleanup

uv python install
uv tool install pre-commit --with pre-commit-uv

[ ! -L "${HOMEBREW_PREFIX}/bin/sha256sum" ] && ln -s "${HOMEBREW_PREFIX}/bin/gsha256sum" "${HOMEBREW_PREFIX}/bin/sha256sum"

echo "Installing fzf..."
$HOMEBREW_PREFIX/opt/fzf/install --all --no-bash --no-zsh --no-fish --no-update-rc --key-bindings --completion

for folder in $(echo $STOW_FOLDERS | sed "s/,/ /g"); do
	echo "stow $folder"
	stow -D $folder
	stow --adopt $folder -t $HOME
done

# Stow adopt could override some files, so we need to restore them
git checkout .

bat cache --build

echo "Configuring iTerm2..."
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
echo "Setting fish as default shell..."
sudo sh -c 'echo /opt/homebrew/bin/fish >> /etc/shells'
chsh -s /opt/homebrew/bin/fish

# Install fish plugins
/opt/homebrew/bin/fish -C "fisher update"

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
