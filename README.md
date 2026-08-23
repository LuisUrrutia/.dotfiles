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
./dotfiles install --dry-run
```

Then run the installer when the prompts look right:

```sh
cd "$HOME" \
  && git clone https://github.com/LuisUrrutia/.dotfiles.git \
  && cd .dotfiles \
  && ./dotfiles install
```

Non-owners default to a smaller core install and can answer setup questions like
"Are you working on Web3?", "Are you going to stream?", and "Do you have an
audio interface?" so the installer selects the right optional tool groups.

## What the installer does

`dotfiles install` validates the public command and delegates to `install.sh`.
The Bootstrapper is not just a symlink script. It:

- refuses to run as root or outside macOS
- supports `--dry-run` so you can inspect the plan before sudo, Homebrew,
  cleanup, Stow, shell changes, directory creation, or install-marker writes
- checks Full Disk Access first; when it is missing, it opens System Settings
  and asks to exit by default so you can grant it, restart the terminal, and
  rerun
- checks Xcode Command Line Tools second; when missing, it starts Apple's
  installer and exits before any package work
- requests the sudo password only after those prerequisites and validates it,
  allowing up to three attempts; a protected per-run broker keeps it only in
  memory and serializes concurrent Homebrew `SUDO_ASKPASS` requests, while
  package retries revalidate the broker and ask again if it stops
- probes GitHub web, Git, and release-download routes in parallel before each
  networked phase
- asks plain-language questions, shows the packages/apps behind each yes, then
  maps the answers to optional profile Brewfiles
- installs Homebrew if missing, otherwise updates and upgrades it
- installs the full Xcode app on the first run
- installs `brewfiles/core` plus a temporary Brewfile assembled from
  `brewfiles/profiles/<profile>` files based on your answers or `--profile`
- runs Brew Bundle in parallel, gives Homebrew five chances to finish incomplete
  entries with longer backoff and additional curl retries, and makes the final
  attempt sequential for both installs and downloads to reduce network pressure
- stops before cleanup, Tool Installers, Fish, and the install marker when any
  Brewfile still fails after its retries
- creates `$HOME/.config` and `$HOME/Projects`
- runs tool setup scripts after package install; each script applies config only
  when its app or dependency is available, with Fish saved for last because it
  changes the default shell
- keeps shared Git defaults in the stowed XDG config and writes identity/signing
  values only to machine-local `~/.gitconfig`
- optionally reads a `machines/<hardware-hash>.sh` file to choose an install
  mode, hostname, and local Git identity without storing it in shared Git config
- writes an install marker to `~/.local/state/dotfiles/installed` so first-run
  work does not repeat (a legacy repo-local `.installed` file is still honored
  and cleaned up)

An unauthenticated GitHub API budget can already be exhausted on a fresh Mac.
The Bootstrapper checks GitHub routes and `https://api.github.com/rate_limit`
immediately before Homebrew, mise, TPack, and Neovim instead of treating the
install as one network phase. Homebrew uses its own JSON API, GHCR, vendor
downloads, and Git taps; TPack and Neovim use Git and direct downloads, so none
reserves GitHub core API requests. mise releases use mise's shared version cache
first and only fall back to GitHub's API when necessary. The Bootstrapper
therefore does not require a GitHub login during a fresh install; mise
automatically reuses an existing token or GitHub CLI session when one is already
available. If the anonymous quota is exhausted before mise, the Bootstrapper
waits in interruptible one-minute intervals until GitHub's reported reset. If
mise consumes the final requests and fails, the Bootstrapper confirms the
exhausted quota, waits, rechecks GitHub routes, then retries the incomplete
toolchain without discarding tools that already installed successfully.

Several tool installers have real side effects: macOS defaults, shell
registration, tmux plugin setup, service starts, generated completions,
language toolchains, and app-specific config.

## Install modes

Preview the default interactive plan:

```sh
./dotfiles install --dry-run
```

Core-only install:

```sh
./dotfiles install --core-only
```

Install all optional tool groups via flag:

```sh
./dotfiles install --all-profiles
```

Install selected optional tool groups directly:

```sh
./dotfiles install --profile web3,streaming,audio
./dotfiles install --dry-run --profile blockchain,obs,focusrite
```

Available profile flags: `audio`, `dev`, `formatters`, `languages`, `web3`,
`cloud`, `image`, `productivity`, `streaming`, and `window`. These are the
scriptable names for the same question-driven tool groups.

`brewfiles/profiles/` is the installer's optional-package source of truth, one
Brewfile per profile. Each file starts with `# label:`, `# question:`,
`# summary:`, and optional `# aliases:` header comments that drive the
interactive questions, `--help` text, and `--profile` flag aliases — adding a
profile means adding one file. The installer joins the files selected by
answers or `--profile` into a temporary Brewfile.

The interactive language question behaves like a lightweight checkbox list:
Go, Lua, Rust, and Perl are all enabled by default, and you can answer `n` for
any language toolchain you do not want.

Other optional questions work the same way: say yes to the need, then the
installer immediately asks about each package/app with every item enabled by
default.

## Machines

`machines/` holds one file per known laptop or desktop, named after the
machine's hardware hash. They are tracked config, not ignored private files, so
fork users can add their own machines and keep those choices versioned.

Get this Mac's hardware hash (the script is also on `PATH` as `machash` after
install):

```sh
./tools/bin/config/.local/bin/machash
```

Then create `machines/<hardware-hash>.sh` with plain variables:

```bash
# shellcheck shell=bash disable=SC2034
MACHINE_ID="work-laptop"
MACHINE_NAME="Work Laptop"
MACHINE_HOSTNAME="work-laptop"
MACHINE_INSTALL_MODE="selected"
MACHINE_PROFILES="dev,languages"
MACHINE_GIT_USER_NAME="Your Name"
MACHINE_GIT_USER_EMAIL="you@example.com"
```

Supported variables:

- `MACHINE_ID` and `MACHINE_NAME`: labels shown in install output
- `MACHINE_HOSTNAME`: optional macOS `HostName`, `LocalHostName`, and
  `ComputerName`
- `MACHINE_INSTALL_MODE`: `all`, `core`, or `selected`
- `MACHINE_PROFILES`: comma-separated profile flags when
  `MACHINE_INSTALL_MODE="selected"`
- `MACHINE_GIT_USER_NAME` and `MACHINE_GIT_USER_EMAIL`: written to
  machine-local `~/.gitconfig`
- `MACHINE_GIT_SIGNING_KEY`: optional SSH signing key path or public key
- `MACHINE_GIT_SIGNING_PROGRAM`: optional SSH signing program override

Set `MACHINE_GIT_SIGNING_KEY="~/.ssh/id_ed25519"` when you use a local SSH key
for commit signing. Leave `MACHINE_GIT_SIGNING_PROGRAM` unset unless you need a
non-default signing program.

Do not put passwords, private keys, tokens, or other secrets in `machines/`
files. Public SSH signing keys and app paths are fine.

### Machine-specific agent instructions

Global Claude and Codex instructions share the tracked source at
`tools/ai/AGENTS.md`. The AI Tool Installer links it as
`~/.agents/AGENTS.md`. Because Codex does not discover that location itself,
`~/.codex/AGENTS.md` links to `~/.agents/AGENTS.md`. Claude reads the Stowed
`~/.claude/CLAUDE.md`, whose entire content is `@~/.agents/AGENTS.md`.

For a registered machine, add `machines/<hardware-hash>.agents.md` beside its
Machine Config. The installer links it to `~/.agents/AGENTS_LOCAL.md`, and the
common instructions tell agents to read that file when present. This keeps
different machine workflows tracked without duplicating the common guidance.
An unregistered machine simply has no local instruction link. The installer
never concatenates or generates an effective file, preserves unknown
destinations, and warns when a non-empty `~/.codex/AGENTS.override.md` shadows
the managed Codex instructions.

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
dotfiles tool list
dotfiles tool apply git
dotfiles tool apply fish
dotfiles tool apply vim
```

The direct `tools/<tool>/install.sh` entry points remain available for advanced
use.

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

Applications sometimes replace a Stow symlink with a regular file. Inspect and
resolve that drift through the Config Lifecycle instead of using `stow --adopt`:

```sh
dotfiles config status
dotfiles config status fish
dotfiles config diff <tool> <home-relative-path>
dotfiles config repair <tool> <home-relative-path> --dry-run
dotfiles config repair <tool> <home-relative-path>
```

`repair` handles only missing or byte-identical entries. For a divergent
regular file, explicitly choose `capture` to make the live file authoritative
or `discard` to restore the tracked source; both accept `--dry-run`. Use
`resolve <tool> <path> [--agent claude|codex]` when the right choice needs an
interactive agent discussion. Mutating operations create timestamped safety
backups under `${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/config-backups`.
List them with `dotfiles config backups list`. Pruning is a dry run unless
`--force` is explicit, for example
`dotfiles config backups prune --keep 20 --force`.

## Repository layout

```text
.dotfiles/
├── dotfiles              # Canonical user-facing command
├── brewfiles/
│   ├── core              # Base packages and apps
│   ├── verification      # Verification toolchain
│   └── profiles/         # Selectable profile Brewfiles
├── cli/                  # Focused adapters behind the root dispatcher
├── config/               # Config Lifecycle owner
├── maintenance/          # Update and aggregate Backup owners
├── machines/             # Per-machine config, named <machash>.sh
├── tools/
│   ├── lib.sh            # Shared installer helpers
│   └── <tool>/
│       ├── install.sh    # Tool-specific setup
│       └── config/       # Files stowed into $HOME
├── .githooks/            # Repo-local hooks (gitleaks pre-commit)
├── archived/             # Old configs kept for reference
├── POST_INSTALL.md       # Manual post-install checklist
├── private-install.sh    # Owner-only private setup
├── verification/         # Shared local/CI Verification Suite
└── install.sh            # Main bootstrapper
```

## What's included

- Shell and terminal: Fish, Starship, Ghostty, tmux, fzf, zoxide
- CLI and search: bat, eza, ripgrep, fd, btop, dust, duf, procs, tailspin,
  tlrc, hyperfine, jq, watch, fswatch, rename
- Development: Neovim, Zed, Git with delta, Git LFS, GitHub CLI, tree-sitter,
  actionlint, ShellCheck, gitleaks, and shared cspell dictionaries
- Languages: Node, Python, uv, Bun, Deno, OpenJDK, and .NET via mise, plus
  optional Rust, Go, LuaRocks, and Perl profiles
- macOS/system: GNU core tools, dockutil, mas, mole, Linearmouse, Thaw,
  DisplayLink, The Unarchiver
- Automation and hotkeys: Hammerspoon, skhd
- Apps: Dia, Raycast, 1Password, Ghostty, CleanShot, Fliqlo, IINA, Spotify,
  Discord, WhatsApp, Telegram, Slack, Figma, Zoom
- Security/networking: 1Password CLI, OpenSSH, GnuPG, YubiKey Manager,
  NordVPN, Tailscale, VeraCrypt
- AI tools: Claude, Claude Code, Codex, Ollama, OpenCode config, Claude agent
  profiles
- Optional tool groups: Docker Desktop, Yaak, Android platform tools, AWS,
  Google Cloud, web3 tools, audio/streaming apps

This list is intentionally grouped. The exact package lists live in
`brewfiles/core`, `brewfiles/profiles/`, and
`tools/mise/config/.config/mise/config.toml`.

### Package ownership

Homebrew owns macOS apps, system utilities, native dependencies, and packages
selected through install profiles. The global mise config owns Core Install
runtimes and portable global CLIs, including Claude Code, Codex, and TPack.
Project dependencies remain project-local, and no command has two package
managers.

Versions follow moving channels such as `latest`, `lts`, or a major release;
the repo does not record exact installed versions. During an ownership change,
the Bootstrapper installs and verifies the mise replacement before removing a
known legacy Homebrew package. See
[ADR 0001](docs/adr/0001-own-portable-global-clis-with-mise.md) for the complete
decision.

## Notable workflows

The installed `dotfiles` command is linked into `~/.local/bin`. Every command
supports contextual help, for example `dotfiles help config repair`.

```sh
# Deterministic, offline repository checks
dotfiles verify

# Update installed package managers, tools, plugins, and reference data
dotfiles update
dotfiles update --ignore-schedule

# Back up one app or both concurrently
dotfiles backup thaw
dotfiles backup raycast
dotfiles backup all
```

Update keeps Homebrew work daily-gated and Mole cleanup weekly-gated unless
`--ignore-schedule` is used. It updates toward current versions without
reconciling Brewfile membership, removing manually installed software, or
changing this Git repository. It is also the only owner of periodic Neovim,
TPack, Fish, Skills, and tlrc updates; their installers only establish declared
state. Fish keeps `upd` and `backup-configs` as interactive abbreviations for
the canonical commands.

- Fish has abbreviations for Git, Docker, Brew, common cleanup,
  iCloud/Obsidian paths, and WorkTrunk shell integration. `halp` and `cheat`
  show local command notes inspired by ChristianLempa's cheat-sheets.
- `skill-link [directory]` points `~/.agents/skills` and `~/.claude/skills` at a
  skill you are developing, so edits take effect without reinstalling. It
  defaults to the current directory, requires a `SKILL.md`, and moves an
  installed copy that differs to `~/.agents/skills-backups` before linking.
- Ghostty uses Catppuccin, Monaspice Nerd Font, shell integration, and a
  global quick-terminal toggle on `super+backquote`.
- Starship shows Git, runtimes, Docker, AWS, Google Cloud, duration, status,
  jobs, and time with a Catppuccin palette.
- Neovim is modular, with Lazy, Treesitter, Telescope/frecency, LSP,
  completion, formatting, Fugitive, and diff helpers.
- tmux uses the mise-owned TPack for plugins and validates the config in an
  isolated server before installing plugins.
- Hammerspoon handles Bluetooth sleep/reconnect behavior, caffeinate-at-home
  logic, and hotkeys.
- Raycast exports are tracked as `.rayconfig` backups with `raycast-config`
  helpers for status, listing, backup, restore, and scriptable latest-path lookup.
- Thaw preferences back up with `dotfiles backup thaw`; `dotfiles backup all`
  runs the Thaw and Raycast owners concurrently. Review app backups before
  committing them because they can contain private app state.
- Catppuccin is used across Fish/FZF, Starship, Ghostty, bat, btop, and editor tooling.

## Post-install checklist

The manual steps live in [POST_INSTALL.md](POST_INSTALL.md), which the
installer also prints at the end of every run. Keep that file as the single
source; do not duplicate the list here.

## Customizing

Edit the files under `tools/<tool>/config`, then run
`dotfiles config repair <tool>` or re-run that Tool Installer. When an app has
replaced a symlink, inspect it with `dotfiles config diff` and choose Capture or
Discard explicitly. Declare persistent packages according to
[ADR 0001](docs/adr/0001-own-portable-global-clis-with-mise.md) instead of
installing them only by hand.

Secrets and private credentials belong outside the public repo. Use
`private-install.sh` for owner-only setup instead of committing tokens,
passwords, private keys, or license data here. As a safety net,
`tools/git/install.sh` points this repo's `core.hooksPath` at `.githooks/`,
where a pre-commit hook runs gitleaks over staged changes before every commit.

## Troubleshooting

- Stow conflict: inspect it with `dotfiles config status <tool>` and
  `dotfiles config diff <tool> <path>` before choosing Capture or Discard.
- Missing optional dependency: most `require_*` checks warn and skip that tool.
- Fish did not become the shell: re-run `./tools/fish/install.sh` after
  Homebrew Fish is installed.
- skhd issues: check that Accessibility permissions are granted.
- Homebrew package drift: compare against `brewfiles/core` and
  `brewfiles/profiles/`, then re-run the installer with the matching profiles.

## License

Public dotfiles configuration. Fork and adapt as needed.
