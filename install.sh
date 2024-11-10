#!/usr/bin/env bash

# Only runs in macOS
if [ "$(uname)" != "Darwin" ]; then
	echo "Invalid OS!"
	exit 1
fi

export DOTFILES="${HOME}/.dotfiles"

read -p "Is this a personal computer? (Y/n): " personal
personal=$([[ "$personal" == [Yy] ]] && echo true || echo false)

read -p "Will you work with Web3? (y/n): " web3
web3=$([[ "$web3" == [Yy] ]] && echo true || echo false)

read -p "Will you work with security related tools? (y/n): " security
security=$([[ "$security" == [Yy] ]] && echo true || echo false)

read -p "Will you work with creative tools? (y/n): " creative
creative=$([[ "$creative" == [Yy] ]] && echo true || echo false)

read -p "Will you use an audio interface? (y/n): " audio_interface
audio_interface=$([[ "$audio_interface" == [Yy] ]] && echo true || echo false)

echo "What communication tools would you like to install?"
echo "1. Slack"
echo "2. Microsoft Teams"
echo "3. Zoom"
echo "4. All (default)"
read -p "Enter the number of the communication tool you would like to install: " communication_tool
if [[ -z "$communication_tool" || "$communication_tool" == "4" ]]; then
	communication_tool="1,2,3"
fi
IFS=',' read -r -a communication_tools <<<"$communication_tool"

STOW_FOLDERS="zsh,wget,git,vim,tmux"
CWD="$(pwd)"

sudo -v
while true; do
	sudo -n true
	sleep 60
	kill -0 "$$" || exit
done 2>/dev/null &

# Check if brew is installed, otherwise install it
which -s brew
if [[ $? != 0 ]]; then
	NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
	brew update
	brew upgrade
fi

# Load homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

BREW_PREFIX=$(brew --prefix)

CASK_REPOSITORIES=(
	bramstein/webfonttools
	oven-sh/bun
	aws/tap
)

NORMAL_TOOLS=(
	coreutils      # Install GNU core utilities (those that come with macOS are outdated).
	stow           # Manages symlinks for dotfiles and configurations
	zsh            # Extended Unix shell with more features than bash
	cmake          # Manages project builds and generating makefiles (useful for compiling stuff)
	pkg-config     # Manages compile and link flags for libraries (useful for compiling stuff)
	neovim         # Vim-fork focused on extensibility and usability
	wget           # Internet file retriever
	openssh        # Secure shell (ssh) and secure file transfer (sftp)
	tmux           # Terminal multiplexer
	watchman       # File watching service
	ffmpeg         # Multimedia framework
	gnupg          # GNU Privacy Guard (GPG) for secure communication
	pinentry-mac   # Pinentry for GPG
	jq             # Command-line JSON processor
	yq             # Command-line YAML processor
	bat            # Cat clone with syntax highlighting and Git integration
	git            # Distributed version control system
	git-lfs        # Git extension for versioning large files
	gh             # GitHub CLI
	ykman          # YubiKey Manager CLI
	moreutils      # Collection of additional Unix utilities (like sponge)
	findutils      # GNU find, xargs, and locate, utilities for finding files
	gnu-sed        # macOS uses the BSD version. I prefer the GNU one.
	grep           # macOS uses the BSD version. I prefer the GNU one.
	font-fira-code # Monospaced font with programming ligatures
	font-monaspace # Monospaced font with programming ligatures
	tree           # Display directory structures in a tree-like format
	rename         # Tool for batch renaming files
	zoxide         # Smarter cd command for quick navigation
	ripgrep        # Fast text searching tool (replace to grep, ack)
	p7zip          # 7-Zip (file archiver with high compression ratio)
	aria2          # Lightweight multi-protocol & multi-source command-line download utility
	mas            # Mac App Store command-line interface
	fswatch        # Monitor a directory for changes
	watch          # Executes a program periodically, showing output fullscreen
	rclone         # Rsync for cloud storage
	autossh        # Automatically restart SSH sessions and tunnels
	figlet         # ASCII banner generator
	dockutil       # Command-line tool for managing dock items
	apparency      # Tool for inspecting and manipulating Apple's App Translocation security feature
	fzf            # Command-line fuzzy finder
	fd             # Simple, fast and user-friendly alternative to find
	eza            # Modern, maintained replacement for ls
	exiftool       # Read, write and edit meta information in a wide variety of files
	dust           # More intuitive version of du
	hyperfine      # Command-line benchmarking tool
	procs          # Modern replacement for ps
	forgit         # Utility tool for using git interactively
	git-delta      # Syntax-highlighting pager for git and diff output
	tailspin       # Modern and fast log file viewer
	shfmt          # Shell script formatter

	# Programming languages, version and package managers
	python    # Programming language
	go        # Programming language
	bun       # JavaScript runtime and bundler
	python-tk # Python bindings to the Tk GUI toolkit
	mise      # Tool for managing multiple runtime versions

	# Cloud command-line interfaces
	awscli           # Amazon Web Services command-line interface
	google-cloud-sdk # Google Cloud command-line interface
	aws-sam-cli      # AWS Serverless Application Model command-line interface

	# Image and font manipulation tools
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
	perl 	    # Programming language
	cpanm	    # Perl module installer
	latexindent # Indentation of LaTeX documents
)

CASK_TOOLS=(
	1password                # Password manager
	1password-cli            # Command-line interface for 1Password
	visual-studio-code       # Code editor
	google-chrome            # Web browser
	docker                   # Containerization platform
	postman                  # API development environment
	the-unarchiver           # Unpacks archive files
	grammarly-desktop        # Grammar checker
	surfshark                # VPN
	raycast                  # Command palette for MacOS (replace to Alfred or Spotlight)
	displaylink              # DisplayLink Manager for USB monitors
	spotify                  # Music streaming service
	vlc                      # Media player
	figma                    # Collaborative interface design tool
	font-fira-code-nerd-font # Monospaced font with programming ligatures and icons (used for terminal)
	font-monaspace-nerd-font # Monospaced font with programming ligatures and icons (used for terminal)
	fliqlo                   # Clock screensaver
	iterm2                   # Terminal emulator
	itermai                  # iTerm Artificial Intelligence
	notion                   # Note-taking app
	keyboardcleantool        # Keyboard cleaning tool
	cleanshot 			     # Screen capture tool
)

if [[ $web3 == true ]]; then
	NORMAL_TOOLS+=(
		solidity # Ethereum smart contract language
		ethereum # Installs Ethereum and related tools
	)
fi

if [[ $personal == true ]]; then
	CASK_TOOLS+=(
		telegram              # Messaging app
		discord               # Messaging app
		whatsapp              # Messaging app
		wechat                # Messaging app
		teamviewer            # Remote desktop software
		logitech-g-hub        # Logitech G HUB
		elgato-control-center # Elgato Control Center
		obs                   # Open Broadcaster Software
		keycastr              # Keystroke visualizer
	)
fi

if [[ $security == true ]]; then
	CASK_TOOLS+=(
		http-toolkit           # HTTP debugging proxy
		macfuse                # File system integration
		veracrypt              # Disk encryption
		android-platform-tools # Android SDK Platform-Tools
	)
fi

if [[ $audio_interface == true ]]; then
	CASK_TOOLS+=(
		loopback    # Audio routing software
		soundsource # Audio control software
	)
fi

for tool in "${communication_tools[@]}"; do
	case $tool in
	1)
		CASK_TOOLS+=(
			slack
		)
		;;
	2)
		CASK_TOOLS+=(
			microsoft-teams
		)
		;;
	3)
		CASK_TOOLS+=(
			zoom
		)
		;;
	esac
done

for tool in "${NORMAL_TOOLS[@]}"; do
	brew install ${tool}
done
for cask in "${CASK_REPOSITORIES[@]}"; do
	brew tap ${cask}
done
for tool in "${CASK_TOOLS[@]}"; do
	brew install --cask ${tool}
done

brew cleanup

# Install directly from app store
mas install 975937182 # Fantastical

# Install Rust programming languages to also use tools
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
$HOME/.cargo/bin/cargo install lolcrab

eval "$(/opt/homebrew/bin/mise activate bash)"
mise use -g node@20
mise use -g python@3

pip3 install pre-commit
if [[ $security == true ]]; then
	pip3 install frida-tools
fi

ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"
ln -s "${BREW_PREFIX}/bin/gsed" "${BREW_PREFIX}/bin/sed"

# Configure ZSH and config files
rm $HOME/.zshrc $HOME/.zshenv $HOME/.zlogin
for folder in $(echo $STOW_FOLDERS | sed "s/,/ /g"); do
	echo "stow $folder"
	stow -D $folder
	stow $folder
done

defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "$DOTFILES/iterm"
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

# Create Projects folder
mkdir -p ~/Projects/Personal

# Set MacOS props
sh macos.sh

# Set zsh
chsh -s /bin/zsh

echo "Installation complete!"
echo "Please restart your terminal to apply changes."
echo ""
echo "Possible next steps:"
echo "-> Configure Raycast"
echo "-> Save recovery key in 1Password"
echo "-> Configure 1Password SSH"
echo "-> Settings -> Touch ID -> Enable Apple Watch"
echo "-> 1Password -> Settings -> Apple Watch"
echo "-> Configure CleanShot"
echo "-> Install Insta 360 Link Controller"
echo "-> Configure clock screensaver"
echo "-> Configure Elgato Control Center"
