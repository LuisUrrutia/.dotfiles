# AGENTS.md - Guidelines for AI Coding Agents

This document provides context and guidelines for AI agents working in this macOS dotfiles repository.

## Repository Overview

Personal macOS dotfiles repository managing system configuration, shell environment, development tools, and application settings. Uses **GNU Stow** for symlink management.

### Directory Structure

```
.dotfiles/
├── brewfiles/           # Homebrew bundle files (core, personal)
├── tools/               # Tool-specific configurations
│   ├── lib.sh           # Shared Bash helper functions
│   └── <tool>/          # Per-tool directories
│       ├── install.sh   # Tool-specific setup script
│       └── config/      # Config files (symlinked via Stow)
├── archived/            # Deprecated tools
├── install.sh           # Main installer
└── private-install.sh   # Private/personal install script
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

### Full Installation
```bash
./install.sh              # Interactive install (asks for full/core)
```

### Individual Tool Installation
```bash
./tools/<tool>/install.sh  # Install specific tool (e.g., ./tools/git/install.sh)
```

### Homebrew Package Management
```bash
brew bundle install --file brewfiles/core      # Core packages only
brew bundle install --file brewfiles/personal  # Personal/dev packages
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

1. **No CI/CD**: Changes cannot be automatically validated
2. **macOS only**: Scripts assume macOS and Homebrew
3. **Stow-based**: Config files live in `config/` subdirectories and are symlinked
4. **Owner detection**: `install.sh` checks if user is `luisurrutia` for full install
5. **Two-tier install**: Core tools always installed, personal tools optional
6. **Fish is default shell**: Configured last in install.sh

## Available Helper Functions (lib.sh)

| Function | Purpose | Sets Variable |
|----------|---------|---------------|
| `require_brew_bin <name>` | Check Homebrew binary exists | `$bin_path` |
| `require_brew_opt <name>` | Check Homebrew opt package exists | `$opt_path` |
| `require_app <name>` | Check /Applications app exists | `$app_path` |
| `app_exists <name>` | Check app exists (returns 0/1) | - |
| `run_tool <name>` | Execute tool's install.sh | - |
