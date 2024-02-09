#!/usr/bin/env bash

CWD="$(pwd)"

which -s brew
if [[ $? != 0 ]] ; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  brew update
  brew upgrade
fi

eval "$(/opt/homebrew/bin/brew shellenv)"


BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed

ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"
ln -s "${BREW_PREFIX}/bin/gsed" "${BREW_PREFIX}/bin/sed"


brew install wget

# Install GnuPG
brew install gnupg pinentry-mac

# Install other useful binaries.
brew install zsh tmux neovim
brew install grep openssh mas fzf tree rename cmake pkg-config zoxide
brew install the_silver_searcher fswatch watch
brew install git git-lfs gh
brew install jq bat yq
brew install imagemagick libmagic libavif webp cairo pango jpeg giflib librsvg
brew install python python-tk
brew install p7zip aria2
brew install rclone
brew install autossh
brew install starship
brew install ddcctl

# Install Prezto
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
git clone --recurse-submodules https://github.com/belak/prezto-contrib "${ZDOTDIR:-$HOME}/.zprezto/contrib"
cd $CWD

for file in ${ZDOTDIR:-$HOME}/.zprezto/runcoms/*[^md]
do
  filename=$(basename $file)
  rm "$HOME/.${filename}"
  ln -s "$file" "$HOME/.${filename}"
done

ln -nfs "$HOME/.lsuf/zsh/.zpreztorc" "${ZDOTDIR:-$HOME}/.zpreztorc"

# Add custom loads
if ! grep -q \.lsuf $HOME/.zshrc
then
  echo "for config_file ($HOME/.lsuf/zsh/*.zsh) source \$config_file" >> $HOME/.zshrc
  echo "for config_file ($HOME/.lsuf/env/*.env) source \$config_file" >> $HOME/.zshenv
  echo 'eval "$(starship init zsh)"' >> $HOME/.zshrc
fi

# Install rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install casks
brew tap homebrew/cask-drivers
brew tap ethereum/ethereum
brew tap aws/tap
brew tap bramstein/webfonttools
brew tap homebrew/cask-versions

# Install font tools.
brew install sfnt2woff
brew install woff2

brew install ethereum solidity
brew install kubectl
brew install ykman
brew install go 
brew install node
brew install nvm yarn
brew install awscli google-cloud-sdk aws-sam-cli
brew install bleunlock
brew install --cask warp 
brew install --cask android-platform-tools
brew install --cask docker
brew install --cask google-chrome
brew install --cask sublime-text visual-studio-code
brew install --cask spotify
brew install --cask the-unarchiver
brew install --cask postman
brew install --cask microsoft-teams discord telegram slack whatsapp
brew install --cask displaylink forticlient-vpn
brew install --cask teamviewer
brew install --cask macfuse
brew install --cask veracrypt
brew install --cask http-toolkit
brew install --cask zoom
brew install --cask vlc
brew install --cask grammarly
brew install --cask soundsource
brew install --cask loopback
brew install --cask 1password
brew install --cask 1password/tap/1password-cli

brew install redis

brew install --cask elgato-stream-deck
brew install --cask focusrite-control

# Remove outdated versions from the cellar.
brew cleanup

# Install directly from app store
mas install 1295203466 # Microsoft remote desktop
mas install 1319778037 # iStat menu
mas install 533696630 # Webcam Settings
mas install 441258766 # magnet

pip install pre-commit requests
pip install frida-tools

# Install rvm
gpg --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable --rails

# Install npm packages
mkdir ~/.nvm
npm i -g pnpm lerna

wget https://raw.githubusercontent.com/httptoolkit/frida-android-unpinning/main/frida-script.js -P "$HOME/.lsuf/"

# Config git
ln -nfs "$HOME/.lsuf/git/.gitconfig" "${ZDOTDIR:-$HOME}/.gitconfig"
ln -nfs "$HOME/.lsuf/git/.gitignore" "${ZDOTDIR:-$HOME}/.gitignore"

# Configure wget
ln -nfs "$HOME/.lsuf/others/.wgetrc" "$HOME/.wgetrc"

# Configure starship
ln -nfs "$HOME/.lsuf/starship.toml" "$HOME/.config/starship.toml"

# Configure NeoVim
mkdir -p "$HOME/.config/nvim/colors"
mkdir -p "$HOME/.config/nvim/lua"
/bin/cp -r $HOME/.lsuf/vim/colors/* $HOME/.config/nvim/colors
ln -nfs "$HOME/.lsuf/vim/init.lua" "$HOME/.config/nvim/init.lua"
ln -nfs "$HOME/.lsuf/vim/plugins.lua" "$HOME/.config/nvim/lua/plugins.lua"

git clone https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/opt/packer.nvim

$(brew --prefix)/opt/fzf/install --all

nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

# Install fonts
sh fonts.sh

# Set MacOS props
sh macos.sh

# Set zsh
chsh -s /bin/zsh
