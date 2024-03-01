#!/usr/bin/env bash

# Only runs in macOS
if [ "$(uname)" != "Darwin" ] ; then
	echo "Invalid OS!"
	exit 1
fi

STOW_FOLDERS="zsh,starship,wget,git,vim,warp"
CWD="$(pwd)"

sudo xcodebuild -license

# Check if brew is installed, otherwise install it
which -s brew
if [[ $? != 0 ]] ; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  brew update
  brew upgrade
fi

# Load homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"


BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
brew install stow

#region Install Zsh and Prezto
brew install zsh

# Install casks
brew tap homebrew/cask-drivers
brew tap ethereum/ethereum
brew tap aws/tap
brew tap bramstein/webfonttools
brew tap homebrew/cask-fonts
brew tap homebrew/cask-versions
brew tap oven-sh/bun

# Install binaries for compiling stuff
brew install cmake pkg-config

# Install Security Related tools
brew install gnupg pinentry-mac openssh ykman
brew install --cask http-toolkit macfuse veracrypt
brew install --cask 1password 1password/tap/1password-cli

# Install terminal, multiplexer
brew install tmux
brew install --cask warp

# Install code editors
brew install neovim 
brew install --cask sublime-text visual-studio-code

# Install browsers
brew install --cask google-chrome

# Install file querying/visualization tools
brew install jq bat yq

# Install git related tools
brew install git git-lfs gh

# Install "languages"
brew install python python-tk solidity bun mise go
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh # rust
gpg2 --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable

# Install communication tools
brew install --cask microsoft-teams discord telegram slack whatsapp zoom

# Install media tools
brew install --cask soundsource loopback vlc spotify

# Install docker, kubectl and cloud tools
brew install kubectl awscli google-cloud-sdk aws-sam-cli
brew install --cask docker

# Install font tools.
brew install sfnt2woff woff2

# Install image tools
brew install imagemagick libmagic libavif webp cairo pango jpeg giflib librsvg

# Install web3 tools
brew install ethereum

# Install dbs
brew install redis

# Install CLI useful tools
brew install the_silver_searcher tree rename grep zoxide

# Install some other useful utilities like `sponge`.
brew install moreutils

# Install GNU `find`, `locate`, `updatedb`, and `xargs`
brew install findutils

# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed

# Install fonts
brew install font-fira-code
brew install font-monaspace
brew install --cask font-fira-code-nerd-font
brew install --cask font-monaspace-nerd-font

# Install other useful binaries and tools
brew install p7zip aria2 mas fswatch watch rclone autossh figlet wget dockutil quicklook-json apparency
brew install --cask postman the-unarchiver android-platform-tools grammarly teamviewer displaylink surfshark qlmarkdown adobe-creative-cloud
brew install yarn pnpm # JS package managers
$HOME/.cargo/bin/cargo install lolcrab
$HOME/.cargo/bin/cargo install eza
pip3 install pre-commit frida-tools


ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"
ln -s "${BREW_PREFIX}/bin/gsed" "${BREW_PREFIX}/bin/sed"

# Install directly from app store
mas install 1319778037 # iStat menu
mas install 533696630 # Webcam Settings
mas install 441258766 # magnet
mas install 975937182 # Fantastical

# Remove outdated versions from the cellar.
brew cleanup

# Download certificate unpinning frida script
wget https://raw.githubusercontent.com/httptoolkit/frida-android-unpinning/main/frida-script.js -P "$HOME/.dotfiles/"

rm $HOME/.zshrc $HOME/.zshenv $HOME/.zlogin

for folder in $(echo $STOW_FOLDERS | sed "s/,/ /g")
do
    echo "stow $folder"
    stow -D $folder
    stow $folder
done


/opt/homebrew/bin/dockutil --remove "FaceTime" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.mail" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.TV" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.freeform" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.reminders" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.iCal" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.Music" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.Safari" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.AddressBook" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.Maps" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.iWork.Keynote" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.iWork.Numbers" --no-restart
/opt/homebrew/bin/dockutil --remove "com.apple.iWork.Pages" --no-restart
/opt/homebrew/bin/dockutil --add "/Applications/Warp.app" --after "com.apple.Notes" --no-restart
/opt/homebrew/bin/dockutil --add "/Applications/Visual Studio Code.app" --after "com.apple.Notes" --no-restart
/opt/homebrew/bin/dockutil --add "/Applications/Google Chrome.app" --after "com.apple.Notes" --no-restart
/opt/homebrew/bin/dockutil --add "/Applications/Fantastical.app" --after "com.apple.MobileSMS"

# Create Projects folder
mkdir -p ~/Projects/Personal

# Warp settings
defaults write dev.warp.Warp-Stable FontName -string "\"MonaspiceAr Nerd Font Mono\""
defaults write dev.warp.Warp-Stable Theme -string "{\"Custom\":{\"name\":\"Ocean Hc\",\"path\":\"~/.warp/themes/ocean_hc.yaml\"}}"
defaults write dev.warp.Warp-Stable HonorPS1 -bool true
defaults write dev.warp.Warp-Stable VimModeEnabled -bool true
defaults write dev.warp.Warp-Stable WelcomeTipsCompleted -string true

# Set MacOS props
sh macos.sh

# Set zsh
chsh -s /bin/zsh
