# LuisUrrutia's macOS dotfiles

> [!CAUTION]
> macOS setup. It changes system preferences, installs apps, and
> rewires shell/editor defaults. Read this before running it on a machine you
> care about.

Fish shell, Starship, Ghostty, Neovim, Hammerspoon, Catppuccin, and a
pile of modern CLI tools. The repo uses GNU Stow so tool configs stay versioned
here and symlink into `$HOME`.

## Prerequisites

- macOS with an admin user
- Git
- Homebrew, or permission for the installer to install it
- Sudo access; the installer prompts for your password
- Apple Silicon Homebrew layout (`/opt/homebrew`) is assumed in parts of the installer/config

## Quick install

This is meant for bootstrapping a new Mac, including shared installs for people
who only want parts of the setup. Preview the plan first:

```sh
./install.sh --dry-run
```

Then run the installer when the prompts look right:

```sh
cd "$HOME" \
  && git clone https://github.com/LuisUrrutia/.dotfiles.git \
  && cd .dotfiles \
  && ./install.sh
```

Non-owners default to a smaller core install and can answer setup questions like
"Are you working on Web3?", "Are you going to stream?", and "Do you have an
audio interface?" so the installer selects the right optional tool groups.

## What the installer does

`install.sh` is not just a symlink script. It:

- refuses to run as root or outside macOS
- supports `--dry-run` so you can inspect the plan before sudo, Homebrew,
  cleanup, Stow, shell changes, directory creation, or `.installed` writes
- asks plain-language questions, shows the packages/apps behind each yes, then
  maps the answers to optional profile Brewfiles
- prompts for your password, stores it temporarily in Keychain, and removes it
  on exit
- installs Homebrew if missing, otherwise updates and upgrades it
- installs Xcode on the first run
- installs `brewfiles/core` plus a temporary Brewfile assembled from
  `brewfiles/profiles/<profile>` files based on your answers or `--profile`
- creates `$HOME/.config` and `$HOME/Projects`
- runs tool setup scripts after package install; each script applies config only
  when its app or dependency is available, with Fish saved for last because it
  changes the default shell
- keeps shared Git defaults in the stowed XDG config and writes identity/signing
  values only to machine-local `~/.gitconfig`
- optionally reads `hardware-profiles.sh` machine records to choose an install
  mode, hostname, and local Git identity without storing it in shared Git config
- writes `.installed` so first-run work does not repeat

Several tool installers have real side effects: macOS defaults, shell
registration, tmux plugin setup, service starts, generated completions,
language toolchains, and app-specific config.

## Install modes

Preview the default interactive plan:

```sh
./install.sh --dry-run
```

Core-only install:

```sh
./install.sh --core-only
```

Install all optional tool groups via flag:

```sh
./install.sh --all-profiles
```

Install selected optional tool groups directly:

```sh
./install.sh --profile web3,streaming,audio
./install.sh --dry-run --profile blockchain,obs,focusrite
```

Available profile flags: `audio`, `dev`, `formatters`, `languages`, `web3`,
`cloud`, `image`, `productivity`, `streaming`, and `window`. These are the
scriptable names for the same question-driven tool groups.

`brewfiles/profiles/` is the installer's optional-package source of truth, one
Brewfile per profile. The installer joins the files selected by answers or
`--profile` into a temporary Brewfile.

The interactive language question behaves like a lightweight checkbox list:
Go, Lua, Rust, and Perl are all enabled by default, and you can answer `n` for
any language toolchain you do not want.

Other optional questions work the same way: say yes to the need, then the
installer immediately asks about each package/app with every item enabled by
default.

## Hardware profiles

`hardware-profiles.sh` is the place to describe known laptops or desktops. It is
tracked config, not an ignored private file, so fork users can edit it for their
own machines and keep those choices versioned.

Get this Mac's hardware hash after the Fish config is installed:

```sh
machash
```

Before install, run the helper directly from the repo:

```sh
fish -c 'source tools/fish/config/.config/fish/functions/machash.fish; machash'
```

Then add or update a record in `DOTFILES_HARDWARE_PROFILES`:

```bash
work_laptop="hash=<hardware-hash>"
work_laptop+="|id=work-laptop"
work_laptop+="|name=Work Laptop"
work_laptop+="|hostname=work-laptop"
work_laptop+="|install_mode=selected"
work_laptop+="|profile_list=dev,languages"
work_laptop+="|git_user_name=Your Name"
work_laptop+="|git_user_email=you@example.com"

DOTFILES_HARDWARE_PROFILES=(
  "$work_laptop"
)
```

Supported fields:

- `hash`: required hardware hash from `machash`
- `id` and `name`: labels shown in install output
- `hostname`: optional macOS `HostName`, `LocalHostName`, and `ComputerName`
- `install_mode`: `all`, `core`, or `selected`
- `profile_list`: comma-separated profile flags when `install_mode=selected`
- `git_user_name` and `git_user_email`: written to machine-local `~/.gitconfig`
- `git_signing_key` and `git_signing_program`: optional SSH signing setup

Add signing fields to the same record when you use SSH commit signing.

Do not put passwords, private keys, tokens, or other secrets in
`hardware-profiles.sh`. Public SSH signing keys and app paths are fine.

## Local Git identity

Shared Git defaults are stowed from
`tools/git/config/.config/git/local.gitconfig` into
`~/.config/git/local.gitconfig`. Personal identity and signing settings are
written only to `~/.gitconfig` by `tools/git/install.sh`.

The legacy `tools/git/config/.gitconfig` path is intentionally local-only and
ignored by Git. Keep it on disk if you want a machine-specific file there, but do
not track it as shared repo config.

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
│   └── profiles/         # Selectable profile Brewfiles
├── tools/
│   ├── lib.sh            # Shared installer helpers
│   └── <tool>/
│       ├── install.sh    # Tool-specific setup
│       └── config/       # Files stowed into $HOME
├── archived/             # Old configs kept for reference
├── private-install.sh    # Owner-only private setup
└── install.sh            # Main bootstrapper
```

## What's included

- Shell and terminal: Fish, Starship, Ghostty, tmux, fzf, zoxide, Muxy
- CLI and search: bat, eza, ripgrep, fd, btop, dust, duf, procs, tailspin,
  tlrc, hyperfine, jq, watch, fswatch, rename
- Development: Neovim, Zed, Git with delta, Git LFS, GitHub CLI, actionlint,
  ShellCheck, gitleaks, cspell
- Languages: Node via mise, Python and uv, Bun, OpenJDK, plus optional Rust,
  Go, LuaRocks, and Perl profiles
- macOS/system: GNU core tools, dockutil, mas, mole, Linearmouse, Ice,
  DisplayLink, The Unarchiver
- Automation and hotkeys: Hammerspoon, skhd
- Apps: Dia, Raycast, 1Password, Ghostty, CleanShot, Fliqlo, IINA, Spotify,
  Discord, WhatsApp, Telegram, Slack, Figma, Zoom
- Security/networking: 1Password CLI, OpenSSH, GnuPG, YubiKey Manager,
  NordVPN, Tailscale, VeraCrypt
- AI tools: Claude, Claude Code, OpenCode config, Claude agent profiles
- Optional tool groups: Docker Desktop, Yaak, Android platform tools, AWS,
  Google Cloud, web3 tools, audio/streaming apps

This list is intentionally grouped. The exact package list lives in
`brewfiles/core` and `brewfiles/profiles/`.

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
- Raycast exports are tracked as `.rayconfig` backups with `raycast-config`
  helpers for status, listing, backup, restore, and scriptable latest-path lookup.
- Catppuccin is used across Fish/FZF, Starship, Ghostty, bat, btop, and editor tooling.

## Post-install checklist

- Restart the terminal after install.
- Restore Raycast with `raycast-config restore`, then configure HyperKey in
  Raycast Settings > Advanced.
- Set up 1Password, save the recovery key, and enable the SSH agent.
- Complete CleanShot setup.
- Finish Docker Desktop setup if the `dev` profile was selected.
- Add Bluetooth permission for Hammerspoon in System Settings > Privacy &
  Security > Bluetooth.
- Allow Ghostty under System Settings > Privacy & Security > Developer Tools.
- Set Fliqlo manually as the active screensaver.
- Run `remindctl authorize` to grant Reminders access.
- Install or configure Insta360 Link Controller if needed.
- Configure SoundSource and Loopback licenses if the `audio` profile was selected.
- Configure BusyCal and OBS if their profiles were selected.

## Customizing

Edit the files under `tools/<tool>/config`, then re-run that tool's installer
or restow manually. Add packages to the Brewfiles instead of installing them
only by hand if they should exist on the next machine too.

Secrets and private credentials belong outside the public repo. Use
`private-install.sh` for owner-only setup instead of committing tokens,
passwords, private keys, or license data here.

## Troubleshooting

- Stow conflict: move the existing file out of the way, then re-run the tool installer.
- Missing optional dependency: most `require_*` checks warn and skip that tool.
- Fish did not become the shell: re-run `./tools/fish/install.sh` after
  Homebrew Fish is installed.
- skhd issues: check that Accessibility permissions are granted.
- Homebrew package drift: compare against `brewfiles/core` and
  `brewfiles/profiles/`, then re-run the installer with the matching profiles.

## License

Public dotfiles configuration. Fork and adapt as needed.
