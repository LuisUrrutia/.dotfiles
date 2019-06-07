#!/usr/bin/env bash

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew update
brew upgrade

BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names


# Install `wget` with IRI support.
brew install wget --with-iri

# Install GnuPG to enable PGP-signing commits.
brew install gnupg

# Install more recent versions of some macOS tools.
brew install neovim
brew install grep
brew install openssh

# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install woff2

# Install other useful binaries.
brew install zsh tmux
brew install the_silver_searcher
brew install git git-lfs hub ghi
brew install imagemagick
brew install rename
brew install ssh-copy-id
brew install tree
brew install stormssh
brew install go 
brew install node yarn
brew install python pyenv pyenv-virtualenv 
brew install p7zip
brew install youtube-dl
brew install bat
brew install aria2
brew install libmagic
brew install fasd

# Install casks
brew cask install google-chrome
brew cask install sublime-text
brew cask install spotify
brew cask install skype
brew cask install vlc
brew cask install jetbrains-toolbox
brew cask install tor-browser
brew cask install franz
brew cask install postman
brew cask install docker
brew cask install soapui
brew cask install android-studio
brew cask install the-unarchiver
brew cask install karabiner-elements
brew cask install java
brew cask install iterm2

# Remove outdated versions from the cellar.
brew cleanup

# Install rvm
curl -sSL https://rvm.io/mpapis.asc | gpg --import -
\curl -L https://get.rvm.io | bash -s stable

# Update npm
npm install --global npm

# Install npm packages
npm i -g git-stats speed-test react-native-cli

# Install fonts
cp -f $HOME/.lsuf/fonts/* $HOME/Library/Fonts

# Add OceanicMaterial
/usr/libexec/PlistBuddy -c "Add :'Custom Color Presets':'OceanicMaterial' dict" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Merge 'iterm/OceanicMaterial.itermcolors' :'Custom Color Presets':'OceanicMaterial'" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Add :'Custom Color Presets':'SolarizedDark' dict" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Merge 'iterm/SolarizedDark.itermcolors' :'Custom Color Presets':'SolarizedDark'" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Add :'Custom Color Presets':'Material Design' dict" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Merge 'iterm/material-design-colors.itermcolors' :'Custom Color Presets':'Material Design'" ~/Library/Preferences/com.googlecode.iterm2.plist

# Install Prezto
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"

for file in ${ZDOTDIR:-$HOME}/.zprezto/runcoms/*[^md]
do
  filename=$(basename $file)
  ln -s "$file" "${ZDOTDIR:-$HOME}/.${filename}"
done

ln -nfs "$HOME/.lsuf/zsh/.zpreztorc" "${ZDOTDIR:-$HOME}/.zpreztorc"

# Config git
ln -nfs "$HOME/.lsuf/git/.gitconfig" "${ZDOTDIR:-$HOME}/.gitconfig"
ln -nfs "$HOME/.lsuf/git/.gitignore" "${ZDOTDIR:-$HOME}/.gitignore"

# Add custom loads
echo "for config_file ($HOME/.lsuf/zsh/*.zsh) source \$config_file" >> $HOME/.zshrc
echo "for config_file ($HOME/.lsuf/env/*.env) source \$config_file" >> $HOME/.zshenv

# Configure Karabiner
mkdir -p "$HOME/.config/karabiner/"
ln -nfs "$HOME/.lsuf/others/karabiner.json" "$HOME/.config/karabiner/karabiner.json"

# Configure wget
ln -nfs "$HOME/.lsuf/others/.wgetrc" "$HOME/.wgetrc"

# Configure NeoVim
mkdir -p "$HOME/.config/nvim/bundle"
mkdir -p "$HOME/.config/nvim/colors"
/bin/cp -r $HOME/.lsuf/vim/colors/* $HOME/.config/nvim/colors
ln -nfs "$HOME/.lsuf/vim/init.vim" "$HOME/.config/nvim/init.vim"
git clone https://github.com/VundleVim/Vundle.vim.git "$HOME/.config/nvim/bundle/Vundle.vim"

nvim +PluginInstall +qall

# Set MacOS props
sh macos.sh

# Set zsh
chsh -s /bin/zsh
