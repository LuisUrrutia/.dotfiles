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

# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install woff2

# Install other useful binaries.
brew install neovim
brew install grep openssh mas jump fzf tree rename cmake pkg-config
brew install zsh tmux
brew install the_silver_searcher fswatch watch
brew install git git-lfs gh
brew install jq bat yq
brew install imagemagick libmagic libavif webp cairo pango jpeg giflib librsvg
brew install python python-tk pyenv pyenv-virtualenv 
brew install p7zip aria2 fasd
brew install gdal
brew install rclone
brew install autossh

# Install casks
brew tap homebrew/cask-drivers
brew tap ethereum/ethereum
brew tap aws/tap

brew install ethereum solidity
brew install kubectl
brew install ykman
brew install go 
brew install node
brew install nvm yarn
brew install awscli google-cloud-sdk aws-sam-cli
brew install openjdk@11
brew install --cask docker iterm2
brew install --cask google-chrome
brew install --cask sublime-text jetbrains-toolbox visual-studio-code
brew install --cask spotify
brew install --cask the-unarchiver
brew install --cask postman
brew install --cask microsoft-teams discord telegram
brew install --cask 1password
brew install --cask displaylink forticlient-vpn

brew install redis
brew install --cask pgadmin4


if [[ $(uname -m) != 'arm64' ]]; then
  brew install --cask elgato-stream-deck
  brew install --cask focusrite-control
fi


brew install --cask 1password/tap/1password-cli

# Remove outdated versions from the cellar.
brew cleanup

# Install directly from app store
mas install 1295203466 # Microsoft remote desktop
if [[ $(uname -m) != 'arm64' ]]; then
  mas install 1319778037 # iStat menu
  mas install 533696630 # Webcam Settings
  mas install 441258766 # magnet
fi

# Install visual studio code extensions
code --install-extension ms-vsliveshare.vsliveshare
code --install-extension christian-kohler.npm-intellisense
code --install-extension eamodio.gitlens
code --install-extension vscodevim.vim
code --install-extension ms-python.python
code --install-extension dbaeumer.vscode-eslint
code --install-extension ms-azuretools.vscode-docker
code --install-extension PKief.material-icon-theme
code --install-extension golang.Go
code --install-extension christian-kohler.path-intellisense
code --install-extension EditorConfig.EditorConfig
code --install-extension dotenv.dotenv-vscode
code --install-extension GitHub.copilot
code --install-extension alefragnani.Bookmarks
code --install-extension HashiCorp.terraform
code --install-extension Equinusocio.vsc-material-theme
code --install-extension bradlc.vscode-tailwindcss
code --install-extension ms-vscode.hexeditor
code --install-extension bierner.github-markdown-preview
code --install-extension JuanBlanco.solidity
code --install-extension kamikillerto.vscode-colorize
code --install-extension wayou.vscode-todo-highlight
code --install-extension gruntfuggly.todo-tree
code --install-extension usernamehw.errorlens
code --install-extension steoates.autoimport
code --install-extension aaron-bond.better-comments
code --install-extension aleonardssh.vscord
code --install-extension googlecloudtools.cloudcode
code --install-extension ms-vscode-remote.remote-containers
code --install-extension graphql.vscode-graphql
code --install-extension graphql.vscode-graphql-syntax
code --install-extension graphql.vscode-graphql-execution
code --install-extension davidanson.vscode-markdownlint
code --install-extension ms-ossdata.vscode-postgresql
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension ms-vscode-remote.remote-ssh-edit
code --install-extension sonarsource.sonarlint-vscode
code --install-extension redhat.vscode-xml
code --install-extension redhat.vscode-yaml

# Pyenv versions
pyenv install 3.10:latest
pyenv install 2:latest
pyenv virtualenv $(pyenv versions|grep "^ *3\.10") g3
pyenv virtualenv $(pyenv versions|grep "^ *2\.") g2
pyenv global g3

pip install pre-commit requests

# Install rvm
gpg --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable --rails

# Install npm packages
mkdir ~/.nvm
npm i -g git-stats speed-test truffle ganache
npm i -g pnpm lerna
npm i -g sort-package-json npm-check-updates depcheck syncpack
npm i -g nodemon concurrently

# Add OceanicMaterial
/usr/libexec/PlistBuddy -c "Add :'Custom Color Presets':'OceanicMaterial' dict" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Merge 'iterm/OceanicMaterial.itermcolors' :'Custom Color Presets':'OceanicMaterial'" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Add :'Custom Color Presets':'SolarizedDark' dict" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Merge 'iterm/SolarizedDark.itermcolors' :'Custom Color Presets':'SolarizedDark'" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Add :'Custom Color Presets':'Material Design' dict" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Merge 'iterm/material-design-colors.itermcolors' :'Custom Color Presets':'Material Design'" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Add :'Custom Color Presets':'Material Ocean' dict" ~/Library/Preferences/com.googlecode.iterm2.plist
/usr/libexec/PlistBuddy -c "Merge 'iterm/MaterialOcean.itermcolors' :'Custom Color Presets':'Material Ocean'" ~/Library/Preferences/com.googlecode.iterm2.plist

# Install Prezto
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
git clone --recurse-submodules https://github.com/belak/prezto-contrib "${ZDOTDIR:-$HOME}/.zprezto/contrib"
cd "${ZDOTDIR:-$HOME}/.zprezto/contrib/contrib-prompt/external/spaceship"
git checkout master
git pull
cd $CWD

for file in ${ZDOTDIR:-$HOME}/.zprezto/runcoms/*[^md]
do
  filename=$(basename $file)
  ln -s "$file" "${ZDOTDIR:-$HOME}/.${filename}"
done

ln -nfs "$HOME/.lsuf/zsh/.zpreztorc" "${ZDOTDIR:-$HOME}/.zpreztorc"

# Config git
ln -nfs "$HOME/.lsuf/git/.gitconfig" "${ZDOTDIR:-$HOME}/.gitconfig"
ln -nfs "$HOME/.lsuf/git/.gitignore" "${ZDOTDIR:-$HOME}/.gitignore"

# Config iTerm
ln -nfs "$HOME/.lsuf/iterm/com.googlecode.iterm2.plist" "${ZDOTDIR:-$HOME}/Library/Preferences/com.googlecode.iterm2.plist"

# Add custom loads
if ! grep -q \.lsuf $HOME/.zshrc
then
  echo "for config_file ($HOME/.lsuf/zsh/*.zsh) source \$config_file" >> $HOME/.zshrc
  echo "for config_file ($HOME/.lsuf/env/*.env) source \$config_file" >> $HOME/.zshenv
  echo 'eval "$(pyenv init --path)"' >> ~/.zprofile
fi

# Configure wget
ln -nfs "$HOME/.lsuf/others/.wgetrc" "$HOME/.wgetrc"

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
