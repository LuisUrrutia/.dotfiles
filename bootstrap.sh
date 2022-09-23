#!/usr/bin/env bash

CWD="$(pwd)"

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

eval "$(/opt/homebrew/bin/brew shellenv)"

brew update
brew upgrade

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

# Install GnuPG to enable PGP-signing commits.
brew install gnupg pinentry-mac

# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install woff2

# Install other useful binaries.
brew install neovim
brew install grep openssh mas jump fzf bat
brew install zsh tmux
brew install the_silver_searcher
brew install git git-lfs hub ghi
brew install imagemagick rename tree
brew install go node@16
brew install nvm yarn
brew install python pyenv pyenv-virtualenv 
brew install p7zip aria2 libmagic fasd
brew install awscli cmake openjdk@11 webp libavif

$(brew --prefix)/opt/fzf/install

# Install casks
brew tap homebrew/cask-fonts
brew tap homebrew/cask-drivers
brew tap ethereum/ethereum


brew install font-fira-code
brew install ethereum solidity
brew install kubectl
brew install ykman
brew install --cask google-chrome
brew install --cask sublime-text jetbrains-toolbox visual-studio-code
brew install --cask spotify
brew install --cask postman docker iterm2
brew install --cask the-unarchiver
brew install --cask microsoft-teams discord telegram
brew install --cask 1password
brew install --cask displaylink forticlient-vpn

if [[ $(uname -m) != 'arm64' ]]; then
  brew install --cask elgato-stream-deck
  brew install --cask focusrite-control
fi

brew install --cask font-3270-nerd-font
brew install --cask font-fira-mono-nerd-font
brew install --cask font-inconsolata-go-nerd-font
brew install --cask font-inconsolata-lgc-nerd-font
brew install --cask font-inconsolata-nerd-font
brew install --cask font-monofur-nerd-font
brew install --cask font-overpass-nerd-font
brew install --cask font-ubuntu-mono-nerd-font
brew install --cask font-agave-nerd-font
brew install --cask font-arimo-nerd-font
brew install --cask font-anonymice-nerd-font
brew install --cask font-aurulent-sans-mono-nerd-font
brew install --cask font-bigblue-terminal-nerd-font
brew install --cask font-bitstream-vera-sans-mono-nerd-font
brew install --cask font-blex-mono-nerd-font
brew install --cask font-caskaydia-cove-nerd-font
brew install --cask font-code-new-roman-nerd-font
brew install --cask font-cousine-nerd-font
brew install --cask font-daddy-time-mono-nerd-font
brew install --cask font-dejavu-sans-mono-nerd-font
brew install --cask font-droid-sans-mono-nerd-font
brew install --cask font-fantasque-sans-mono-nerd-font
brew install --cask font-fira-code-nerd-font
brew install --cask font-go-mono-nerd-font
brew install --cask font-gohufont-nerd-font
brew install --cask font-hack-nerd-font
brew install --cask font-hasklug-nerd-font
brew install --cask font-heavy-data-nerd-font
brew install --cask font-hurmit-nerd-font
brew install --cask font-im-writing-nerd-font
brew install --cask font-iosevka-nerd-font
brew install --cask font-jetbrains-mono-nerd-font
brew install --cask font-lekton-nerd-font
brew install --cask font-liberation-nerd-font
brew install --cask font-meslo-lg-nerd-font
brew install --cask font-monoid-nerd-font
brew install --cask font-mononoki-nerd-font
brew install --cask font-mplus-nerd-font
brew install --cask font-noto-nerd-font
brew install --cask font-open-dyslexic-nerd-font
brew install --cask font-profont-nerd-font
brew install --cask font-proggy-clean-tt-nerd-font
brew install --cask font-roboto-mono-nerd-font
brew install --cask font-sauce-code-pro-nerd-font
brew install --cask font-shure-tech-mono-nerd-font
brew install --cask font-space-mono-nerd-font
brew install --cask font-terminess-ttf-nerd-font
brew install --cask font-tinos-nerd-font
brew install --cask font-ubuntu-nerd-font
brew install --cask font-victor-mono-nerd-font

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
code --install-extension mikestead.dotenv
code --install-extension GitHub.copilot
code --install-extension alefragnani.Bookmarks
code --install-extension HashiCorp.terraform
code --install-extension Equinusocio.vsc-material-theme
code --install-extension bradlc.vscode-tailwindcss
code --install-extension ms-vscode.hexeditor
code --install-extension icrawl.discord-vscode
code --install-extension bierner.github-markdown-preview
code --install-extension JuanBlanco.solidity
code --install-extension kamikillerto.vscode-colorize

# Pyenv versions
pyenv install 3.10:latest
pyenv install 2:latest
pyenv virtualenv $(pyenv versions|grep "^ *3\.10") g3
pyenv virtualenv $(pyenv versions|grep "^ *2\.") g2
pyenv global g3


# Install rvm
curl -sSL https://rvm.io/mpapis.asc | gpg --import -
\curl -L https://get.rvm.io | bash -s stable

# Install npm packages
npm i -g git-stats speed-test truffle ganache

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

# Add custom loads
echo "for config_file ($HOME/.lsuf/zsh/*.zsh) source \$config_file" >> $HOME/.zshrc
echo "for config_file ($HOME/.lsuf/env/*.env) source \$config_file" >> $HOME/.zshenv
echo 'eval "$(pyenv init --path)"' >> ~/.zprofile

# Configure wget
ln -nfs "$HOME/.lsuf/others/.wgetrc" "$HOME/.wgetrc"

# Configure NeoVim
mkdir -p "$HOME/.config/nvim/colors"
/bin/cp -r $HOME/.lsuf/vim/colors/* $HOME/.config/nvim/colors
ln -nfs "$HOME/.lsuf/vim/init.lua" "$HOME/.config/nvim/init.lua"

git clone https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/opt/packer.nvim

$(brew --prefix)/opt/fzf/install --all

# Set MacOS props
sh macos.sh

# Set zsh
chsh -s /bin/zsh
