# LuisUrrutia's macOS Dotfiles

> [!CAUTION]
> Personal dotfiles for macOS. Use at your own risk.

Fish shell, Starship prompt, Catppuccin theme, and modern CLI tools.

## Quick Install

```sh
cd $HOME && git clone https://github.com/LuisUrrutia/.dotfiles.git && cd .dotfiles && ./install.sh
```

The installer detects if you're the repo owner. Non-owners get a minimal install option.

## Structure

```
.dotfiles/
├── brewfiles/
│   ├── core           # Essential tools (always installed)
│   └── personal       # Development tools, apps (full install only)
├── tools/
│   ├── lib.sh         # Shared functions for install scripts
│   ├── <tool>/
│   │   ├── install.sh # Tool-specific setup script
│   │   └── config/    # Config files (symlinked via GNU Stow)
│   └── ...
└── install.sh         # Main installer
```

### Tool Install Scripts

Each tool has its own `install.sh` that:
- Sources `tools/lib.sh` for shared functions
- Checks if dependencies exist before running
- Skips gracefully if the tool isn't installed

Available helper functions in `lib.sh`:
- `require_brew_bin <name>` - Require a Homebrew binary (exits if missing)
- `require_brew_opt <name>` - Require a Homebrew opt package (exits if missing)
- `require_app <name>` - Require a macOS app (exits if missing)
- `app_exists <name>` - Check if a macOS app exists (returns true/false)
- `run_tool <name>` - Run a tool's install script

## What's Included

**Shell**: Fish, Starship, tmux, fzf, zoxide

**CLI Tools**: bat, eza, ripgrep, fd, btop, dust, delta

**Development**: Neovim, Git (with delta), gh CLI

**Languages** (full install): Node.js (fnm), Python (uv), Rust, Go, Bun

**Window Management**: Hammerspoon, (full install) yabai, skhd

**Apps**: kitty, Raycast, 1Password, Brave, Docker

## Post-Install

- Configure Raycast (HyperKey in Settings > Advanced)
- Set up 1Password SSH agent
- Complete Docker Desktop setup
- Add Bluetooth permissions to Hammerspoon

## License

Personal configuration. Fork and adapt as needed.
