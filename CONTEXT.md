# macOS Dotfiles Context

This context defines the domain language for this personal macOS dotfiles repository. It helps agents discuss bootstrap behavior, tool configuration, and safe setup changes without mixing them with unrelated knowledge workflows.

## Language

**Dotfiles Repository**:
A personal macOS setup repo that manages system preferences, shell environment, developer tools, apps, and application settings.
_Avoid_: Generic config repo, package list

**Bootstrapper**:
The root `install.sh` script that prepares a Mac, installs packages, runs tool installers, stows configs, and applies first-run setup.
_Avoid_: Symlink script, setup helper

**Tool Directory**:
A directory under `tools/<tool>/` that owns one tool's installer and versioned config.
_Avoid_: Plugin, module

**Tool Installer**:
The `tools/<tool>/install.sh` script that installs or configures one tool, usually by calling shared helpers and stowing that tool's config.
_Avoid_: Package installer, post-install hook

**Stowed Config**:
Files under `tools/<tool>/config` that GNU Stow links into `$HOME`.
_Avoid_: Copied config, generated config

**Brewfile**:
A Homebrew bundle file under `brewfiles/` that declares packages and apps for repeatable setup.
_Avoid_: Dependency manifest, manual install list

**Core Install**:
The safer install path that applies base packages and configs without owner-only extras.
_Avoid_: Minimal mode, demo install

**Full Install**:
The owner-oriented install path that includes personal packages and broader setup.
_Avoid_: Default install, production install

**Private Setup**:
Owner-only setup driven by `private-install.sh`, which pulls private configuration outside the public repo before running its installer.
_Avoid_: Local override, secret config

**Shared Installer Helpers**:
Functions in `tools/lib.sh` that provide dependency checks, tool execution, and Stow helpers for Bash installers.
_Avoid_: Utility script, common code

**Fish Shell Config**:
Interactive shell configuration, functions, abbreviations, paths, and environment setup for Fish.
_Avoid_: Bash profile, terminal theme

**macOS Automation Config**:
Hammerspoon, yabai, skhd, borders, and related settings that control windows, spaces, hotkeys, and system behavior.
_Avoid_: App preferences, desktop theme

**Safe Bootstrap Convention**:
A setup rule that prevents damage during install, such as refusing root, requiring macOS, warning non-owners, skipping missing optional dependencies, and avoiding blind Stow conflict overwrites.
_Avoid_: Defensive coding, error suppression

## Relationships

- The **Dotfiles Repository** is meant to bootstrap and maintain a personal macOS environment.
- The **Bootstrapper** installs Homebrew packages from **Brewfiles**, runs **Tool Installers**, and stows **Stowed Config** into `$HOME`.
- Each **Tool Directory** owns its own **Tool Installer** and any **Stowed Config** for that tool.
- **Shared Installer Helpers** keep Bash installer behavior consistent across **Tool Installers**.
- **Core Install** is available to non-owners; **Full Install** adds personal packages and setup for the repo owner.
- **Private Setup** belongs outside the public repository and must not leak credentials or machine-local secrets.
- **Fish Shell Config** is installed late because it can change the default shell.
- **macOS Automation Config** can have system-level side effects, so it should follow **Safe Bootstrap Convention**.

## Example Dialogue

> **Dev:** "Should a tool config be copied into `$HOME`?"
> **Domain expert:** "No. Keep it under `tools/<tool>/config` and use GNU Stow so the repo remains the source of truth."

> **Dev:** "Should a new CLI package be installed by hand only?"
> **Domain expert:** "No. Add it to the right Brewfile if it should appear on the next machine too."

> **Dev:** "Can a tool installer fail when an optional app is missing?"
> **Domain expert:** "Usually no. Use the shared `require_*` helpers so optional dependencies warn and skip cleanly."

> **Dev:** "Should owner-only credentials live in this repo?"
> **Domain expert:** "No. Keep private or machine-local settings outside the public repo and use `private-install.sh` for owner-only setup."

> **Dev:** "Can Fish be installed anywhere in the bootstrap order?"
> **Domain expert:** "No. Run Fish last because it can change the default shell."

## Flagged Ambiguities

- "Install" can mean full bootstrap or one tool reinstall. Prefer **Bootstrapper** for `./install.sh` and **Tool Installer** for `tools/<tool>/install.sh`.
- "Config" can mean tracked files or live files in `$HOME`. Prefer **Stowed Config** for tracked files linked into place by GNU Stow.
- "Personal" can mean public preferences or private secrets. Public preferences may live in this repo; **Private Setup** and secrets must stay outside it.
- "Package drift" means Homebrew state differs from **Brewfiles**. Resolve it by updating the Brewfile or re-running `brew bundle install --file <file>`.
