#!/usr/bin/env bash

# Only runs in macOS
if [ "$(uname)" != "Darwin" ]; then
	echo "Invalid OS!"
	exit 1
fi

STOW_FOLDERS="zsh,wget,git,vim,tmux,starship,bat,btop,linearmouse"
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
BREW_PREFIX=$(brew --prefix)

CASK_REPOSITORIES=(
	bramstein/webfonttools
	aws/tap
)

NORMAL_TOOLS=(
	# Core System Tools
	coreutils      # Install GNU core utilities (those that come with macOS are outdated).
	stow           # Manages symlinks for dotfiles and configurations
	zsh            # Extended Unix shell with more features than bash
	cmake          # Manages project builds and generating makefiles
	pkg-config     # Manages compile and link flags for libraries
	gnupg          # GNU Privacy Guard (GPG) for secure communication
	moreutils      # Collection of additional Unix utilities (like sponge)
	findutils      # GNU find, xargs, and locate, utilities for finding files
	gnu-sed        # macOS uses the BSD version. I prefer the GNU one.
	grep           # macOS uses the BSD version. I prefer the GNU one.

	# Development Tools
	neovim         # Vim-fork focused on extensibility and usability
	git            # Distributed version control system
	git-lfs        # Git extension for versioning large files
	gh             # GitHub CLI
	forgit         # Utility tool for using git interactively
	git-delta      # Syntax-highlighting pager for git and diff output
	shfmt          # Shell script formatter

	# Network and Security
	wget           # Internet file retriever
	openssh        # Secure shell (ssh) and secure file transfer (sftp)
	autossh        # Automatically restart SSH sessions and tunnels
	ykman          # YubiKey Manager CLI
	rclone         # Rsync for cloud storage
	mosh           # Remote terminal application

	# Terminal Enhancement
	tmux           # Terminal multiplexer
	starship       # Shell prompt
	btop           # Resource monitor
	bat            # Cat clone with syntax highlighting and Git integration
	eza            # Modern, maintained replacement for ls
	procs          # Modern replacement for ps
	tailspin       # Modern and fast log file viewer
	figlet         # ASCII banner generator
	hyperfine      # Command-line benchmarking tool

	# File Management and Search
	tree           # Display directory structures in a tree-like format
	rename         # Tool for batch renaming files
	zoxide         # Smarter cd command for quick navigation
	ripgrep        # Fast text searching tool (replace to grep, ack)
	fzf            # Command-line fuzzy finder
	fd             # Simple, fast and user-friendly alternative to find
	fswatch        # Monitor a directory for changes
	watch          # Executes a program periodically, showing output fullscreen
	dust           # More intuitive version of du

	# Media and File Processing
	ffmpeg         # Multimedia framework
	p7zip          # 7-Zip (file archiver with high compression ratio)
	aria2          # Lightweight multi-protocol & multi-source command-line download utility
	exiftool       # Read, write and edit meta information in a wide variety of files

	# System Management
	mas            # Mac App Store command-line interface
	dockutil       # Command-line tool for managing dock items
	apparency      # Tool for inspecting and manipulating Apple's App Translocation security feature

	# Fonts
	font-fira-code # Monospaced font with programming ligatures
	font-monaspace # Monospaced font with programming ligatures

	# Programming Languages and Package Managers
	python          # Programming language
	uv              # Tool for managing multiple runtime versions
	go              # Programming language
	oven-sh/bun/bun # JavaScript runtime and bundler
	fnm             # Fast Node Manager

	# Cloud Tools
	awscli           # Amazon Web Services command-line interface
	google-cloud-sdk # Google Cloud command-line interface
	aws-sam-cli      # AWS Serverless Application Model command-line interface

	# Image and Font Processing
	sfnt2woff   # Convert TrueType fonts to WOFF format
	woff2       # WOFF 2.0 font compression
	imagemagick # Image manipulation tools
	libmagic    # File type identification library
	libavif     # AVIF image format reference implementation
	webp        # Image format that provides lossless and lossy compression for images on the web
	cairo       # 2D graphics library with support for multiple output devices
	pango       # Library for layout and rendering of text
	jpeg        # Image manipulation library
	giflib      # Library for reading and writing gif images
	librsvg     # Library for rendering SVG files
	libvips     # Image processing library
	perl        # Programming language
	cpanm       # Perl module installer
	latexindent # Indentation of LaTeX documents

	# Web3 Development
	solidity    # Ethereum smart contract language
	ethereum    # Installs Ethereum and related tools
	stellar-cli # Stellar CLI
)

CASK_TOOLS=(
	# Development Tools
	cursor                   # Code editor
	postman                  # API development environment
	http-toolkit             # HTTP debugging proxy
	android-platform-tools   # Android SDK Platform-Tools

	# Security and Privacy
	1password                # Password manager
	1password-cli            # Command-line interface for 1Password
	nordvpn                  # VPN
	veracrypt                # Disk encryption
	macfuse                  # File system integration

	# Communication and Collaboration
	telegram                 # Messaging app
	discord                  # Messaging app
	whatsapp                 # Messaging app
	slack                    # Work Messaging app
	zoom                     # Work video conferencing
	teamviewer               # Remote desktop software

	# Web Browsers
	brave-browser            # Web browser

	# Design and Media
	figma                    # Collaborative interface design tool
	iina                     # Media player
	obs                      # Open Broadcaster Software
	cleanshot                # Screen capture tool

	# Development Infrastructure
	docker                   # Containerization platform

	# Productivity
	raycast                  # Command palette for MacOS (replace to Alfred or Spotlight)
	notion                   # Note-taking app
	fliqlo                   # Clock screensavers

	# Terminal and System
	iterm2                   # Terminal emulator
	itermai                  # iTerm Artificial Intelligence
	keyboardcleantool        # Keyboard cleaning tool
	hyperkey                 # Remap caps lock to hyper key

	# Audio Tools
	focusrite-control-2      # Audio interface
	loopback                 # Audio routing software
	soundsource              # Audio control software

	# Fonts
	font-fira-code-nerd-font # Monospaced font with programming ligatures and icons (used for terminal)
	font-monaspace-nerd-font # Monospaced font with programming ligatures and icons (used for terminal)

	# Entertainment
	spotify                  # Music streaming service

	# Hardware Support
	displaylink              # DisplayLink Manager for USB monitors
	linearmouse              # Mouse handler

	# File Management
	the-unarchiver           # Unpacks archive files
)

for tool in "${NORMAL_TOOLS[@]}"; do
	brew install -q ${tool}
done
for cask in "${CASK_REPOSITORIES[@]}"; do
	brew tap ${cask}
done
for tool in "${CASK_TOOLS[@]}"; do
	brew install -q --cask ${tool}
done

brew cleanup

# Install directly from app store
mas install 975937182 # Fantastical

# Install Rust programming languages to also use tools
if [ ! -f "$HOME/.cargo/bin/cargo" ]; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -q
fi
$HOME/.cargo/bin/cargo install lolcrab

uv python install

[ ! -L "${BREW_PREFIX}/bin/sha256sum" ] && ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"
[ ! -L "${BREW_PREFIX}/bin/sed" ] && ln -s "${BREW_PREFIX}/bin/gsed" "${BREW_PREFIX}/bin/sed"

# Configure ZSH and config files
rm $HOME/.zshrc $HOME/.zshenv $HOME/.zlogin
for folder in $(echo $STOW_FOLDERS | sed "s/,/ /g"); do
	echo "stow $folder"
	stow -D $folder
	stow $folder
done

bat cache --build

defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "$DOTFILES/iterm"
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

# Create Projects folder
mkdir -p ~/Projects/LuisUrrutia

# Set MacOS props
sh macos.sh

# Restore Cursor settings
sh cursor.sh

# Set zsh if not already default shell
if [[ "$SHELL" != "/bin/zsh" ]]; then
	chsh -s /bin/zsh
fi

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
