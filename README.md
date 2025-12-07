# LuisUrrutia's macOS Dotfiles

> [!CAUTION]
> These are PERSONAL dotfiles and configurations specifically designed for macOS. Use at your own risk and adapt to your needs.

A comprehensive macOS development environment setup with a focus on modern tools, productivity, and aesthetics. This setup uses Fish shell, Starship prompt, and a carefully curated collection of CLI tools and applications.

## ✨ Features

- **🐟 Fish Shell**: Modern shell with intelligent autocompletion and syntax highlighting
- **🚀 Starship Prompt**: Fast, customizable prompt with git integration
- **📦 Homebrew**: Package management with extensive tool collection
- **🔗 GNU Stow**: Dotfiles management via symlinks
- **🎨 Catppuccin Theme**: Consistent theming across all applications
- **⚡ Performance Optimizations**: Fast terminal, optimized git settings, efficient completions
- **🔧 Development Tools**: Complete setup for multiple programming languages
- **🖥️ macOS Tweaks**: System optimizations and security enhancements
- **🪟 yabai**: Tiling window manager with automatic space management
- **🔨 Hammerspoon**: Automation for Bluetooth, sleep management, and location-aware settings

## 🚀 Quick Install

```sh
cd $HOME && git clone https://github.com/LuisUrrutia/.dotfiles.git && cd .dotfiles && ./install.sh
```

## 📋 What Gets Installed

### 🛠️ Core System Tools

- **GNU Coreutils**: Modern Unix tools (coreutils, findutils, gnu-sed, grep)
- **Stow**: Symlink management for dotfiles
- **Fish + Fisher**: Shell and plugin manager
- **GPG**: Secure communication and signing

### 🧑‍💻 Development Environment

- **Git**: Version control with delta diff viewer and advanced aliases
- **Neovim**: Modern Vim editor
- **Zed**: Fast, collaborative code editor
- **Claude Code**: AI-powered coding assistant
- **GitHub CLI**: Command-line GitHub integration
- **Language Support**: Python (uv), Node.js (fnm), Go, Rust, Bun
- **Blockchain**: Foundry (forge, cast, anvil)
- **Cloud Tools**: AWS CLI, Google Cloud CLI

### 🔧 Command Line Tools

- **Terminal Enhancers**: tmux, starship, btop, bat, eza, procs
- **Search & Navigation**: ripgrep, fzf, fd, zoxide
- **File Management**: rename, p7zip, exiftool, dust
- **Network Tools**: wget, openssh, autossh, mosh, rclone, aria2
- **Media Processing**: ffmpeg, yt-dlp, imagemagick
- **Monitoring**: tailspin (log viewer), fswatch, hyperfine (benchmarking)

### 🎨 Applications (via Homebrew Cask)

- **Development**: Zed, Yaak, Docker Desktop, Android Platform Tools
- **Browsers**: Brave Browser
- **Security**: 1Password, NordVPN, VeraCrypt
- **Communication**: Telegram, Discord, WhatsApp, Slack, Zoom
- **Media & Design**: Figma, OBS, CleanShot, Adobe Creative Cloud
- **Productivity**: Raycast, Notion, BusyCal, Ice (menu bar organizer)
- **Terminal**: kitty
- **Audio**: Focusrite Control, Loopback, SoundSource
- **System**: Hyperkey, DisplayLink, MacFUSE

### ⚙️ Configuration Files

| Tool | Configuration | Description |
|------|---------------|-------------|
| Fish | `~/.config/fish/config.fish` | Shell configuration with Catppuccin theme |
| Git | `~/.gitconfig` | Advanced git aliases, delta integration, GPG signing |
| Zed | `~/.config/zed/settings.json` | Code editor settings |
| kitty | `~/.config/kitty/kitty.conf` | Terminal configuration |
| Starship | `~/.config/starship.toml` | Shell prompt configuration |
| yabai | `~/.config/yabai/` | Tiling window manager configuration |
| Hammerspoon | `~/.hammerspoon/` | macOS automation scripts |

## 🐟 Fish Shell Productivity

### Custom Functions

- **`gwclone`**: Git clone with worktree support and auto-detected default branch
- **`gwnb`**: Create and switch to new git worktree branches
- **`upup`**: One-command update for Homebrew, pnpm, and Fisher
- **`nuke`**: Kill resource-heavy background processes (Adobe, Logitech, etc.)
- **`awss`**: AWS profile switcher
- **`mkd`**: Create directory and cd into it

### Abbreviations

50+ shell abbreviations for common operations:
- **Git**: `gst`, `gco`, `gcm`, `gp`, `gl`, `grb`, `amend`, `uncommit`, worktree ops (`gwl`, `gwa`, `gwrm`)
- **Docker**: `dps`, `dexec`, `dc`, `dcu`, `dcd`
- **System**: `brewup`, `localip`, `clean-js`

## 🔨 Hammerspoon Automation

### Bluetooth Sleep Manager
- Disconnects Bluetooth devices on sleep, reconnects on wake
- Prevents battery drain on sleeping machines

### Location-Aware Settings
- Detects home WiFi networks
- Prevents system sleep when on home network
- Enables stricter security settings when away

## 🔐 Private Configuration (Optional)

For personal configurations that shouldn't be public:

```sh
./private-install.sh
```

This installs additional private configurations for:

- Cursor (private settings/extensions)
- Fish (work-specific configurations)
- Sensitive configurations

## 🍎 macOS System Optimizations

The setup includes comprehensive macOS system tweaks via `macos.sh`:

### ⌨️ Keyboard & Input

- Disable automatic text corrections and smart features
- Fast key repeat rate
- Full keyboard access for all controls

### 🖥️ Display & Screen

- Subpixel font rendering for external displays
- Secure screen saver settings
- Screenshot organization

### 📁 Finder & Files

- Show all file extensions
- Secure trash emptying
- Reveal hidden folders

### ⚡ Performance & Security

- Automatic software updates
- Firewall configuration
- FileVault disk encryption
- Power management optimization

### 🎯 Application Tweaks

- Dock customization and app management
- Disabled system shortcuts (replaced with better alternatives)
- Keyboard shortcut customization

## 📚 Installation Process

1. **System Check**: Verifies macOS compatibility
2. **Homebrew**: Installs or updates package manager
3. **Package Installation**: Installs all tools from Brewfile
4. **Configuration Linking**: Uses Stow to symlink dotfiles
5. **Software Configuration**: Applies specific software configuration
6. **System Configuration**: Applies macOS tweaks
7. **Shell Setup**: Configures Fish as default shell
8. **Final Setup**: Builds caches and applies final configurations

## ✅ Post-Installation Tasks

After running the installer, complete these manual steps:

### Essential Configuration

- [ ] **Raycast**: Configure launcher and productivity shortcuts
- [ ] **1Password**: Set up SSH agent and Apple Watch integration
- [ ] **Touch ID**: Enable Apple Watch for authentication

### Development Setup

- [ ] **Docker**: Complete Docker Desktop setup and licensing

### Productivity Apps

- [ ] **CleanShot**: Configure screenshot automation
- [ ] **Clock Screensaver**: Set up custom screensaver
- [ ] **Hyperkey**: Configure caps lock key remapping
- [ ] **BusyCal**: Set up calendar integration
- [ ] **OBS**: Configure streaming/recording setup

### Audio/Video Setup

- [ ] **SoundSource & Loopback**: Apply audio software licenses
- [ ] **Insta360 Link Controller**: Install webcam software
- [ ] **Focusrite Control**: Configure audio interface

## 🖥️ My Setup

### Hardware

- 💻 **Laptop**: MacBook Pro M3 Max (64GB RAM)
- 🖥️ **Monitor**: ASUS ProArt PA279CRV
- ⌨️ **Keyboard**: ROG Azoth
- 🖱️ **Mouse**: Logitech G502 X Plus
- 🖱️ **Mousepad**: Razer Strider XXL

### Audio Setup

- 🎧 **Headphones**: Sennheiser HD 490 Pro
- 🎤 **Microphone**: Oktava MK-012S
- 🔊 **Audio Interface**: Scarlett 2i2 4th Generation

### Accessories

- 📹 **Webcam**: Insta360 Link or iPhone 16 Pro Max
- 💡 **Lightbar**: BenQ ScreenBar Pro

## 🐛 Troubleshooting

### Common Issues

- **Permission errors**: Ensure script has execute permissions
- **Homebrew failures**: Check internet connection and disk space
- **Stow conflicts**: Remove existing config files before running
- **SSH authentication**: Verify GitHub SSH key setup for private configs

### Getting Help

- Check individual tool documentation
- Review installation logs for specific errors
- Ensure macOS version compatibility

## 📄 License

This is a personal configuration repository. Feel free to fork and adapt for your own use.
