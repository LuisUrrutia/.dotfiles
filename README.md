# LuisUrrutia's macOS dotfiles

> [!CAUTION]
> Personal macOS setup. It changes system preferences, installs apps, and
> rewires shell/editor defaults. Read this before running it on a machine you
> care about.

Fish shell, Starship, Ghostty, Neovim, Hammerspoon, yabai, Catppuccin, and a
pile of modern CLI tools. The repo uses GNU Stow so tool configs stay versioned
here and symlink into `$HOME`.

## Prerequisites

- macOS with an admin user
- Git
- Homebrew, or permission for the installer to install it
- Sudo access; the installer prompts for your password
- Apple Silicon Homebrew layout (`/opt/homebrew`) is assumed in parts of the installer/config

## Quick install

This is meant for bootstrapping a new personal Mac. It installs Homebrew
packages, may install Xcode on first run, runs per-tool setup scripts, stows
configs into `$HOME`, and applies macOS defaults.

```sh
cd "$HOME" \
  && git clone https://github.com/LuisUrrutia/.dotfiles.git \
  && cd .dotfiles \
  && ./install.sh
```

Non-owners are warned and can choose a smaller install path that skips the
personal Brewfile.

## What the installer does

`install.sh` is not just a symlink script. It:

- refuses to run as root or outside macOS
- prompts for your password, stores it temporarily in Keychain, and removes it
  on exit
- installs Homebrew if missing, otherwise updates and upgrades it
- installs Xcode on the first run
- installs `brewfiles/core`, and `brewfiles/personal` for full installs
- creates `$HOME/.config`
- runs every `tools/<tool>/install.sh`, with Fish saved for last because it
  changes the default shell
- removes the personal Git identity from tracked Git config for non-owners on
  first run
- writes `.installed` so first-run work does not repeat

Several tool installers have real side effects: macOS defaults, shell
registration, tmux plugin setup, yabai sudoers config, service starts,
generated completions, language toolchains, and app-specific config.

## Install modes

Full install:

```sh
./install.sh
```

Install or re-run one tool config:

```sh
./tools/git/install.sh
./tools/fish/install.sh
./tools/vim/install.sh
```

Private config, for the repo owner only:

```sh
./private-install.sh
```

That script checks GitHub SSH auth, clones/pulls the private repo into
`private/`, then runs its installer.

## Stow notes

Most tool installers call `stow_config <tool>`, which runs Stow from
`tools/<tool>` into `$HOME`.

Useful manual commands:

```sh
# Preview links for one tool
stow -n -v -d "$HOME/.dotfiles/tools/git" -t "$HOME" config

# Restow one tool
stow --restow -d "$HOME/.dotfiles/tools/git" -t "$HOME" config

# Remove one tool's symlinks
stow -D -d "$HOME/.dotfiles/tools/git" -t "$HOME" config
```

If Stow reports conflicts, move or back up the existing files first. Do not
blindly overwrite home-directory config unless you know which version you want.

## Repository layout

```text
.dotfiles/
├── brewfiles/
│   ├── core              # Base packages and apps
│   └── personal          # Full-install extras
├── cursor/               # Cursor settings
├── tools/
│   ├── lib.sh            # Shared installer helpers
│   └── <tool>/
│       ├── install.sh    # Tool-specific setup
│       └── config/       # Files stowed into $HOME
├── archived/             # Old configs kept for reference
├── cursor.sh             # Cursor helper
├── private-install.sh    # Owner-only private setup
└── install.sh            # Main bootstrapper
```

## What's included

- Shell and terminal: Fish, Starship, Ghostty, tmux, fzf, zoxide, cmux
- CLI and search: bat, eza, ripgrep, fd, btop, dust, duf, procs, tailspin,
  tlrc, hyperfine, jq, watch, fswatch, rename
- Development: Neovim, Zed, Git with delta, Git LFS, GitHub CLI, actionlint,
  ShellCheck, gitleaks, cspell
- Languages: Node via fnm, Python and uv, Bun, OpenJDK, plus Rust, Go,
  LuaRocks, Perl in full installs
- macOS/system: GNU core tools, dockutil, mas, mole, Linearmouse, Ice,
  DisplayLink, The Unarchiver
- Automation and windows: Hammerspoon, yabai, skhd, borders
- Apps: Arc, Raycast, 1Password, Ghostty, CleanShot, Fliqlo, IINA, Spotify,
  Discord, WhatsApp, Zoom
- Security/networking: 1Password CLI, OpenSSH, GnuPG, YubiKey Manager,
  NordVPN, Tailscale, VeraCrypt
- AI tools: Claude, Claude Code, OpenCode config, Claude agent profiles
- Full-install extras: Docker Desktop, Yaak, HTTP Toolkit, Android platform
  tools, AWS, Google Cloud, web3 tools, audio/streaming/design apps

This list is intentionally grouped. The exact package list lives in
`brewfiles/core` and `brewfiles/personal`.

## Notable workflows

- Fish has abbreviations for Git, Docker, Brew, common cleanup,
  iCloud/Obsidian paths, and WorkTrunk shell integration. `halp` and `cheat`
  show local command notes inspired by ChristianLempa's cheat-sheets.
- Ghostty uses Catppuccin, Monaspice Nerd Font, shell integration, and a
  global quick-terminal toggle on `super+backquote`.
- Starship shows Git, runtimes, Docker, AWS, Google Cloud, duration, status,
  jobs, and time with a Catppuccin palette.
- Neovim is modular, with Lazy, Treesitter, Telescope/frecency, LSP,
  completion, formatting, Fugitive, and diff helpers.
- tmux uses TPack for plugins and validates the config in an isolated server before
  installing plugins.
- Hammerspoon handles Bluetooth sleep/reconnect behavior, caffeinate-at-home
  logic, and hotkeys.
- yabai creates named spaces, routes apps to displays/spaces, applies
  sticky/unmanaged rules, and has Ghostty-specific window fixes.
- Raycast exports are tracked as `.rayconfig` backups with `raycast-config`
  helpers for status, listing, backup, restore, and scriptable latest-path lookup.
- Catppuccin is used across Fish/FZF, Starship, Ghostty, bat, btop, and editor tooling.

## Post-install checklist

- Restart the terminal after install.
- Restore Raycast with `raycast-config restore`, then configure HyperKey in
  Raycast Settings > Advanced.
- Set up 1Password, save the recovery key, and enable the SSH agent.
- Complete CleanShot setup.
- Finish Docker Desktop setup for full installs.
- Add Bluetooth permission for Hammerspoon in System Settings > Privacy &
  Security > Bluetooth.
- Allow Ghostty under System Settings > Privacy & Security > Developer Tools.
- Set Fliqlo manually as the active screensaver.
- Run `remindctl authorize` to grant Reminders access.
- Install or configure Insta360 Link Controller if needed.
- Configure SoundSource and Loopback licenses for full installs.
- Configure BusyCal and OBS for full installs.

## Customizing

Edit the files under `tools/<tool>/config`, then re-run that tool's installer
or restow manually. Add packages to the Brewfiles instead of installing them
only by hand if they should exist on the next machine too.

Machine-local or private settings belong outside the public repo. Use
`private-install.sh` for owner-only setup instead of committing secrets or
personal credentials here.

## Troubleshooting

- Stow conflict: move the existing file out of the way, then re-run the tool installer.
- Missing optional dependency: most `require_*` checks warn and skip that tool.
- Fish did not become the shell: re-run `./tools/fish/install.sh` after
  Homebrew Fish is installed.
- yabai/skhd issues: check permissions, scripting additions, and the sudoers
  setup created by the installer.
- Homebrew package drift: compare against `brewfiles/core` and
  `brewfiles/personal`, then re-run `brew bundle install --file <file>`.

## License

Personal configuration. Fork and adapt as needed.
