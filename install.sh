#!/usr/bin/env bash

CWD="$(pwd)"

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
  # Loads all env/*.env files
  echo "for config_file ($HOME/.lsuf/env/*.env) source \$config_file" >> $HOME/.zshenv
  # Loads all zsh/*.zsh files
  echo "for config_file ($HOME/.lsuf/zsh/*.zsh) source \$config_file" >> $HOME/.zshrc
  # Configure starship
  echo 'eval "$(starship init zsh)"' >> $HOME/.zshrc
  # Print random phrase on new shell
  echo 'random_phrase' >> $HOME/.zshrc
fi
#endregion

# Install casks
brew tap homebrew/cask-drivers
brew tap ethereum/ethereum
brew tap aws/tap
brew tap bramstein/webfonttools
brew tap homebrew/cask-versions
brew tap oven-sh/bun

# Install binaries for compiling stuff
brew install cmake pkg-config

# Install Security Related tools
brew install gnupg pinentry-mac openssh ykman
brew install --cask http-toolkit macfuse veracrypt
brew install --cask 1password 1password/tap/1password-cli

# Install terminal, multiplexer and prompt
brew install tmux starship
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
brew install python python-tk solidity go node bun
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh # rust
gpg --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable --rails

# Install communication tools
brew install --cask microsoft-teams discord telegram slack whatsapp zoom

# Install media tools
brew install --cask soundsource loopback vlc spotify focusrite-control

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
brew install wget

# Install other useful binaries and tools
brew install p7zip aria2 mas fswatch watch rclone autossh figlet
brew install --cask postman the-unarchiver android-platform-tools grammarly teamviewer displaylink
brew install yarn pnpm # JS package managers
cargo install lolcrab
cargo install eza
pip install pre-commit frida-tools


ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"
ln -s "${BREW_PREFIX}/bin/gsed" "${BREW_PREFIX}/bin/sed"

# Install directly from app store
mas install 1319778037 # iStat menu
mas install 533696630 # Webcam Settings
mas install 441258766 # magnet




# Remove outdated versions from the cellar.
brew cleanup



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
nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

# Install fonts
sh fonts.sh

# Set MacOS props
sh macos.sh

# Set zsh
chsh -s /bin/zsh
