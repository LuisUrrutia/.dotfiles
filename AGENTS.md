# AGENTS.md - Guidelines for AI Coding Agents

This document provides context and guidelines for AI agents working in this macOS dotfiles repository.

## Repository Overview

Shareable macOS dotfiles repository managing system configuration, shell environment, development tools, and application settings. Uses **GNU Stow** for symlink management.

### Directory Structure

```
.dotfiles/
├── brewfiles/           # Homebrew bundle files (core, profiles)
├── tools/               # Tool-specific configurations
│   ├── lib.sh           # Shared Bash helper functions
│   └── <tool>/          # Per-tool directories
│       ├── install.sh   # Tool-specific setup script
│       └── config/      # Config files (symlinked via Stow)
├── archived/            # Deprecated tools
├── hardware-profiles.sh # Tracked per-machine profile records
├── install.sh           # Main installer
└── private-install.sh   # Owner-only private install script
```

### Languages Used

| Language | Usage | Indentation |
|----------|-------|-------------|
| Bash | Install scripts, macOS configuration | 2 spaces |
| Fish | Shell configuration, functions | 4 spaces |
| Lua (Hammerspoon) | macOS automation | 4 spaces |
| Lua (Neovim) | Editor configuration | 2 spaces |
| TOML/JSON | Configuration files | 2 spaces |

## Build/Install Commands

### Interactive Installation
```bash
./install.sh              # Interactive install (asks which profiles to install)
```

### Individual Tool Installation
```bash
./tools/<tool>/install.sh  # Install specific tool (e.g., ./tools/git/install.sh)
```

### Homebrew Package Management
```bash
brew bundle install --file brewfiles/core      # Core packages only
brew bundle install --file brewfiles/profiles/web3  # One optional profile
```

## Code Style Guidelines

### EditorConfig Rules (enforced)
- All files: LF line endings, UTF-8, trim trailing whitespace, final newline
- Bash/Zsh: 2-space indentation
- Fish: 4-space indentation
- Lua: 4-space indentation (Hammerspoon), 2-space (Neovim config)
- Python: 4-space indentation
- .gitconfig: Tab indentation

### Bash Script Conventions

```bash
#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

# Use require_* functions for graceful dependency handling
require_brew_bin git    # Sets $bin_path, exits 0 if missing
require_brew_opt nodejs # Sets $opt_path, exits 0 if missing
require_app "App Name"  # Sets $app_path, exits 0 if missing

# Use stow for symlinking config directories
stow -d "$DOTFILES/tools/<tool>" -t "$HOME" config
```

**Key patterns:**
- Shebang: `#!/usr/bin/env bash`
- Source lib.sh at the start of install scripts
- Use helper functions from lib.sh for dependency checks
- Graceful exit (exit 0) when optional dependencies are missing
- Quote all variable expansions: `"$variable"`
- Use `[[ ]]` for conditionals, not `[ ]`

### Fish Script Conventions

```fish
# Guard for interactive sessions at file start
status is-interactive || exit

# Function definition with description
function myfunction -d "Brief description"
    # Function body
end

# Environment variables
set -gx VARIABLE_NAME "value"

# Abbreviations (preferred over aliases)
abbr -a -- gs 'git status'
```

**Key patterns:**
- Guard interactive-only code with `status is-interactive || exit`
- Use `-d "description"` flag for function documentation
- Prefer abbreviations (`abbr`) over aliases for git/common commands
- Use `set -gx` for exported environment variables
- Use `set -l` for local variables

### Lua Conventions (Hammerspoon)

```lua
--[[
Module description block
--]]

local mod = {}

local log = hs.logger.new('module_name')

-- JSDoc-style comments for functions
-- @param paramName type - Description
-- @return type - Description
function mod.public_function()
    -- Implementation
end

local function private_function()
    -- Implementation
end

return mod
```

**Key patterns:**
- Module pattern: local table returned at end
- Logger initialization: `hs.logger.new('name')`
- JSDoc-style comments: `-- @param`, `-- @return`
- Private functions use `local function`
- Public functions assigned to module table

### Lua Conventions (Neovim)

```lua
-- Modular imports
require("config.module")

-- Inline comments explaining each option
vim.opt.number = true  -- print line numbers
```

**Key patterns:**
- 2-space indentation (differs from Hammerspoon)
- Inline comments explaining vim options
- Modular config structure under `lua/config/`

## Naming Conventions

### Files and Directories
- Tool directories: lowercase, hyphen-separated (`line-mouse` not `linearmouse`)
- Fish config.d files: numbered prefix for load order (`00_homebrew.fish`, `01_paths.fish`)
- Install scripts: always named `install.sh`

### Variables
- Bash: UPPER_SNAKE_CASE for exports, lower_snake_case for locals
- Fish: UPPER_SNAKE_CASE for exports, lower_snake_case for locals
- Lua: snake_case for variables and functions

### Functions
- Bash: snake_case (`require_brew_bin`)
- Fish: snake_case with hyphens allowed (`fish_user_key_bindings`)
- Lua: snake_case (`is_powered_on`)

## Error Handling

### Bash
- Use `set -euo pipefail` in lib.sh (inherited by install scripts)
- Warn and exit 0 for missing optional dependencies (graceful skip)
- Exit 1 for actual errors

### Fish
- Use `and` for chained commands: `mkdir -p $dir and cd $dir`
- Return non-zero for function errors: `return 1`

### Lua
- Use `if` guards for nil checks
- Log errors via `hs.logger`

## Theming

The repository uses **Catppuccin** theme consistently across tools:
- Fish, bat, btop, Ghostty, Neovim all use Catppuccin variants
- FZF colors are configured in `config.fish`

## Important Notes for Agents

1. **CI is lint-focused**: GitHub Actions runs shell/static checks; still run
   narrow local validation before claiming success
2. **macOS only**: Scripts assume macOS and Homebrew
3. **Stow-based**: Config files live in `config/` subdirectories and are symlinked
4. **Hardware profiles are tracked config**: `hardware-profiles.sh` is meant
   for users to edit for their laptops/desktops; do not add it to `.gitignore`
   or treat it as disposable private state
5. **No secrets in tracked profiles**: Hardware profiles may contain public SSH
   signing keys and local app paths, but never tokens, private keys, passwords,
   or license data
6. **Owner detection**: `install.sh` may default owner prompts differently, but
   install behavior is profile-based
7. **Profile installs**: Core tools always installed, optional tools come from
   `brewfiles/profiles/`
8. **Fish is default shell**: Configured last in install.sh
9. **Git config split**: Shared Git defaults are tracked at
   `tools/git/config/.config/git/local.gitconfig`; machine identity/signing is
   written to `~/.gitconfig`
10. **Local legacy Git config**: `tools/git/config/.gitconfig` is intentionally
    ignored/local-only; do not delete the user's local copy when removing it from
    Git tracking
11. **Git migration safety**: `tools/git/migrate-config.sh` must not write
    through non-managed `~/.gitconfig` or `~/.config/git` symlinks; preserve
    manual migration errors
12. **Tool installer boundaries**: A `tools/<tool>/install.sh` script must not
    invoke another tool's installer. `install.sh` orchestrates all tools, so
    cross-tool setup belongs in the owning tool or shared `tools/lib.sh` helpers
13. **Domain docs**: Read `CONTEXT.md` before architecture, diagnosis, TDD, or
    issue-writing work
14. **Glossary ownership**: Keep domain language in `CONTEXT.md`; do not
    duplicate the glossary here

## Hardware Profile Rules

`install.sh` loads `hardware-profiles.sh` only when the file is readable. Keep
`DOTFILES_HARDWARE_PROFILES=()` as the default so public clones and test
fixtures can run without records.

Each record is a pipe-delimited `key=value` string. Supported keys are `hash`,
`id`, `name`, `hostname`, `install_mode`, `profile_list`, `git_user_name`,
`git_user_email`, `git_signing_key`, and `git_signing_program`.

`install_mode` accepts `all`, `core`, or `selected`. When using `selected`,
`profile_list` must contain comma-separated profile flags from `PROFILE_ORDER`.

Hardware profile values are exported for tool installers through
`DOTFILES_HARDWARE_*`, `DOTFILES_GIT_*`, and `DOTFILES_MANAGED_GIT_*` variables.
When no hardware profile matches, preserve caller-provided `GIT_USER_NAME`,
`GIT_USER_EMAIL`, `GIT_SIGNING_KEY`, and `GIT_SIGNING_PROGRAM` fallbacks.

## Git Config Rules

The Git tool has two layers:

- Shared, stowed defaults: `tools/git/config/.config/git/local.gitconfig` ->
  `~/.config/git/local.gitconfig`
- Machine-local identity/signing: `~/.gitconfig`, created or updated by
  `tools/git/install.sh`

Do not reintroduce tracked identity into the shared Git config. Do not track
`tools/git/config/.gitconfig`; it is ignored so users can keep a local file
without publishing identity settings.

`tools/git/migrate-config.sh` keeps the include for
`~/.config/git/local.gitconfig` first in `~/.gitconfig`, backs up old non-symlink
`~/.config/git/local.gitconfig` files, and refuses non-managed symlinks instead
of mutating their targets.

When editing this area, validate at minimum:

```bash
bash -n install.sh hardware-profiles.sh \
  tools/git/install.sh tools/git/migrate-config.sh tools/macos/install.sh
fish -n tools/fish/config/.config/fish/functions/machash.fish
shellcheck install.sh hardware-profiles.sh \
  tools/git/install.sh tools/git/migrate-config.sh tools/macos/install.sh
git config --file tools/git/config/.config/git/local.gitconfig --list >/dev/null
```

## Available Helper Functions (lib.sh)

| Function | Purpose | Sets Variable |
|----------|---------|---------------|
| `require_brew_bin <name>` | Check Homebrew binary exists | `$bin_path` |
| `require_brew_opt <name>` | Check Homebrew opt package exists | `$opt_path` |
| `require_app <name>` | Check /Applications app exists | `$app_path` |
| `app_exists <name>` | Check app exists (returns 0/1) | - |
| `run_tool <name>` | Execute tool's install.sh | - |

## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues for `LuisUrrutia/.dotfiles`. See `docs/agents/issue-tracker.md`.

### Triage labels

The triage vocabulary uses the default mattpocock/skills labels. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repo using root `CONTEXT.md` and root `docs/adr/`. See `docs/agents/domain.md`.
