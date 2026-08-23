# macOS Dotfiles Context

This context defines the domain language for this shareable macOS dotfiles repository. It helps agents discuss bootstrap behavior, tool configuration, and safe setup changes without mixing them with unrelated knowledge workflows.

## Language

**Dotfiles Repository**:
A shareable macOS setup repo that manages system preferences, shell environment, developer tools, apps, and application settings.
_Avoid_: Generic config repo, package list

**Dotfiles Command**:
A single user-facing management interface for the Dotfiles Repository that coordinates existing capability owners without replacing them.
_Avoid_: Replacement installer, monolithic setup script

**Inspection Command**:
A Dotfiles Command operation whose objective is to observe and report state;
finding drift or another condition is a successful inspection when observation
itself was trustworthy.
_Avoid_: Health command, passive action

**Action Command**:
A Dotfiles Command operation whose objective is to change state; it succeeds
only when the requested state was achieved or was already satisfied.
_Avoid_: Mutation command, write command

**Verification Suite**:
The deterministic offline checks that determine whether the Dotfiles Repository is internally consistent and safe to use, shared unchanged by local development and CI.
_Avoid_: CI checks, local checks

**Verification Toolchain**:
The declared set of external tools required to run the Verification Suite consistently on a maintained Mac or a disposable CI runner.
_Avoid_: CI dependencies, runner packages

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

**Managed Config Entry**:
One eligible source path in a Stowed Config and its corresponding live target under `$HOME`, owned independently from shared parent directories and application runtime state.
_Avoid_: Whole config directory, every file below a Stow package

**Config Drift**:
A Managed Config Entry whose live target is no longer the exact managed link, classified without assuming whether tracked or live content should win.
_Avoid_: Package drift, automatic adoption

**Agent Resolution Session**:
An interactive Claude or Codex session that inspects a specific Config Drift,
discusses intent with the operator, and may perform the chosen resolution.
_Avoid_: Config advisor, unattended repair

**Effective Agent Instructions**:
The global operating instructions presented consistently to local coding agents,
consisting of one tracked common source that directs agents to an optional
tracked machine-specific instruction source.
_Avoid_: Claude-only instructions, Codex-only instructions

**Brewfile**:
A Homebrew bundle file under `brewfiles/` that declares packages and apps for repeatable setup.
_Avoid_: Dependency manifest, manual install list

**Package Owner**:
The single tracked manager responsible for installing and updating a persistent
app, runtime, native utility, or portable global command.
_Avoid_: Preferred installer, duplicate fallback

**Core Install**:
The safer install path that applies base packages and configs without owner-only extras.
_Avoid_: Minimal mode, demo install

**Profile Install**:
An optional install path assembled from selected Brewfiles under `brewfiles/profiles/`, driven by answers in `install.sh` or explicit `--profile` flags.
_Avoid_: Owner install, monolithic extras install

**Machine Config**:
A tracked `machines/<hardware-hash>.sh` record that supplies public labels and default installation choices for one known Mac, plus machine-local Git settings consumed only by their owning installer.
_Avoid_: Hardware profile, private machine state

**Registered Machine**:
A Mac whose current hardware hash matches a tracked Machine Config. Registration supplies defaults but is not required to run the Bootstrapper.
_Avoid_: Authorized machine, owner machine

**Software Maintenance**:
The explicit workflow that updates installed package managers, tools, plugins, and their owner-specific housekeeping without synchronizing the Dotfiles Repository or enforcing Brewfile membership.
_Avoid_: Repository update, package reconciliation

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
Hammerspoon, skhd, and related settings that control hotkeys and system behavior.
_Avoid_: App preferences, desktop theme

**Safe Bootstrap Convention**:
A setup rule that prevents damage during install, such as refusing root, requiring macOS, warning non-owners, skipping missing optional dependencies, and avoiding blind Stow conflict overwrites.
_Avoid_: Defensive coding, error suppression

## Relationships

- The **Dotfiles Repository** is meant to bootstrap and maintain a shareable macOS environment.
- The **Dotfiles Command** exposes installation and maintenance capabilities while their existing owners retain responsibility for behavior.
- The **Dotfiles Command** runs the **Verification Suite** using the **Verification Toolchain**; CI provisions that toolchain and invokes the same command.
- The **Bootstrapper** installs Homebrew packages from **Brewfiles**, runs **Tool Installers**, and stows **Stowed Config** into `$HOME`.
- The **Bootstrapper** loads environments established during the current run
  before invoking dependent **Tool Installers**; it never relies on restarting
  the terminal or loading interactive shell configuration.
- Every persistent package has one **Package Owner**; ownership changes install
  and verify the replacement before retiring the former owner.
- Each **Tool Directory** owns its own **Tool Installer** and any **Stowed Config** for that tool.
- A **Stowed Config** owns individual **Managed Config Entries**; **Config Drift** requires an explicit lifecycle decision rather than blind adoption.
- An **Agent Resolution Session** may resolve **Config Drift** interactively while
  the operator retains control of intent and provider access.
- **Effective Agent Instructions** use common guidance plus an optional
  machine-specific source selected by **Machine Config**.
- **Shared Installer Helpers** keep Bash installer behavior consistent across **Tool Installers**.
- **Core Install** is always available; **Profile Install** adds optional packages based on the user's answers.
- A **Registered Machine** receives installation defaults from its **Machine Config**; an unregistered Mac may still choose a Core Install or Profile Install manually.
- **Software Maintenance** changes installed software without changing the
  Dotfiles Repository or enforcing that installed software exactly matches a
  Brewfile.
- **Private Setup** belongs outside the public repository and must not leak credentials or machine-local secrets.
- **Fish Shell Config** is installed late because it can change the default shell.
- **macOS Automation Config** can have system-level side effects, so it should follow **Safe Bootstrap Convention**.

## Example Dialogue

> **Dev:** "Should a tool config be copied into `$HOME`?"
> **Domain expert:** "No. Keep it under `tools/<tool>/config` and use GNU Stow so the repo remains the source of truth."

> **Dev:** "Where should a persistent CLI package be declared?"
> **Domain expert:** "Give it one Package Owner. The ownership ADR assigns apps,
> system utilities, and native dependencies to Brewfiles; portable global CLIs
> and runtimes belong to mise; project dependencies stay project-local."

> **Dev:** "Can a tool installer fail when an optional app is missing?"
> **Domain expert:** "Usually no. Use the shared `require_*` helpers so optional dependencies warn and skip cleanly."

> **Dev:** "Should owner-only credentials live in this repo?"
> **Domain expert:** "No. Keep private or machine-local settings outside the public repo and use `private-install.sh` for owner-only setup."

> **Dev:** "Can Fish be installed anywhere in the bootstrap order?"
> **Domain expert:** "No. Run Fish last because it can change the default shell."

## Flagged Ambiguities

- "Install" can mean full bootstrap or one tool reinstall. Prefer **Bootstrapper** for `./install.sh` and **Tool Installer** for `tools/<tool>/install.sh`.
- "Config" can mean tracked files or live files in `$HOME`. Prefer **Stowed Config** for tracked files linked into place by GNU Stow.
- Use **Profile Install** for public optional packages and **Private Setup** for owner-only or secret material.
