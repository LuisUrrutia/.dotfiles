# Agent Guide

This is a shareable, macOS-only dotfiles repository. GNU Stow keeps tracked
configuration in `tools/<tool>/config` and links it into `$HOME`.

## Source Map

Load only the source relevant to the current branch of work:

- `README.md`: installation, profiles, machines, package ownership, repository
  layout, and user-facing workflows.
- `CONTEXT.md`: domain language. Read it before architecture, diagnosis, TDD,
  or issue-writing work; keep glossary definitions there.
- `.editorconfig`: formatting and indentation. It is the formatting source of
  truth.
- `.github/workflows/ci.yml`: CI events, runner, and Verification Toolchain
  provisioning. `verification/groups/` holds the checks it runs.
- `dotfiles` and `cli/*.sh`: root routing, public grammar, help, and thin
  adapter boundaries.
- `install.sh` and `bootstrap/`: fresh-Mac orchestration and GitHub preflight.
- `config/run.sh`, `maintenance/`, and `verification/`: lifecycle,
  maintenance, and repository-check owners.
- `tools/lib.sh`: Shared Installer Helpers and their current interfaces.
- `tools/hammerspoon/AGENTS.md`: verified macOS platform constraints for
  Hammerspoon or screen-lock work.

Read implementations before changing them. Documentation describes intent;
the executable path defines current behavior.

## Completion Gate

An implementation is complete only when all applicable gates pass:

1. Run the narrowest behavioral test for the changed contract.
2. Run syntax and static checks used by CI for the changed languages.
3. Run one broader smoke path outside the changed feature.
4. Run `git diff --check` and inspect the final diff for unintended state.

For Bootstrapper or Profile Install changes, include the relevant macOS Bash
3.2 `/bin/bash install.sh --dry-run ...` modes from CI.

For Stowed Config changes, restow every package into a temporary HOME using
`--no-folding`; a clean simulation is required before completion.

For machine or identity changes, include secret scanning and the Git-specific
checks below. Report exact commands and outcomes; name any unavailable check and
its blocker.

## Universal Invariants

### Safe Bootstrap

Follow the **Safe Bootstrap Convention** from `CONTEXT.md`: preserve user state,
make destructive intent explicit, and degrade gracefully when an optional app
or command is unavailable. Actual errors return nonzero.

App-updated settings may replace a managed symlink with a regular file. Treat
that as config drift: inspect and diff it, back it up, then require an explicit
capture or discard decision. Blind `stow --adopt` and overwriting unknown live
targets are unsafe.

For a real interactive Bootstrapper run, the first user-facing prerequisites
are Full Disk Access, Xcode Command Line Tools, and validated sudo credentials,
in that order. Missing Full Disk Access defaults to an early exit; missing
Command Line Tools starts Apple's installer and exits. The operator can finish
the macOS flow and rerun without wasting installation work.

Run each Brewfile with Bundle-owned parallelism and bounded whole-Brewfile
retries; installed entries make retries incremental. A final Bundle failure may
continue to other Brewfiles, but blocks cleanup, Tool Installers, first-run
tasks, and the install marker.

### Ownership

The Bootstrapper orchestrates Tool Installers. A `tools/<tool>/install.sh`
owns only its Tool Directory and never invokes another Tool Installer. Shared
cross-tool behavior belongs in the Bootstrapper or `tools/lib.sh`.

Follow the package-ownership ADR; never introduce a second manager for an
existing command. Retire a legacy owner only after the new owner has installed
and verified its replacement.

### Public State

Machine configs are tracked configuration. Preserve `machines/<hash>.sh` and
never add the directory to `.gitignore`. Public signing keys and local app paths
are acceptable; tokens, passwords, private keys, licenses, sessions, logs,
caches, and databases stay outside tracked state.

### Predictable Defaults

Global CLI configs must preserve predictable script behavior. Stateful or
interactive policies that resume, rename, skip, hide, or page data belong behind
explicit flags, functions, or interactive abbreviations.

Independent maintenance tasks continue after failures, collect
completed/skipped/warning/failed outcomes, and return nonzero when any critical
task fails. Write gate stamps after mutations succeed and before advisory
diagnostics.

## Installer Work

Use Bash 3.2-compatible syntax in scripts that run before Homebrew. Shell
scripts use `#!/usr/bin/env bash`, quoted expansions, `[[ ]]`, and
`set -euo pipefail` through `tools/lib.sh`.

Tool Installers source:

```bash
source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"
```

Use `require_brew_bin`, `require_brew_opt`, and `require_app` for optional
dependencies. They set `bin_path`, `opt_path`, and `app_path` and exit cleanly
when the dependency is absent. Use `stow_config <tool>` for per-file links.

## Global Agent Instructions

`tools/ai/AGENTS.md` is the tracked common source. The `ai` Tool Installer owns
these links:

- `~/.agents/AGENTS.md` -> the tracked common source
- `~/.codex/AGENTS.md` -> `~/.agents/AGENTS.md`, because Codex does not discover
  the `.agents` location itself
- `~/.agents/AGENTS_LOCAL.md` ->
  `machines/<hardware-hash>.agents.md` when that Registered Machine source exists

The common source tells agents to read `~/.agents/AGENTS_LOCAL.md` when present.
Claude uses the Stowed `~/.claude/CLAUDE.md`, whose entire content is
`@~/.agents/AGENTS.md`. Do not concatenate or generate common and local
instructions.

Preserve unknown regular files and foreign symlinks at every destination.
Preserve a non-empty `~/.codex/AGENTS.override.md` and warn that it shadows the
managed Codex instructions. Remove a stale local link only when it is a known
managed link into `machines/*.agents.md`.

## Fish Work

Human-only behavior starts after an interactive guard. This includes secrets,
prompt setup, abbreviations, and other presentation policy.

Preserve caller-provided environment values with default-only assignments, for
example:

```fish
set -q PAGER; or set -gx PAGER less
```

Keep raw CLI behavior available to subprocesses and agents. Apply user-only
policy through an explicit Fish function plus an interactive abbreviation, not
a globally exported config variable.

Functions include `-d "description"`; exported state uses `set -gx`, local state
uses `set -l`, and interactive shorthand uses abbreviations rather than aliases.

After Fish changes, run `fish --no-execute` over every Fish file, then execute
matching `tools/fish/tests/*.sh` scripts with Bash. Software Maintenance changes
require `bash maintenance/tests/update.sh`; its Fish abbreviation and migration
seam additionally require `bash tools/fish/tests/upd.sh`.

## Machine And Git Work

Read the machine and Git sections in `README.md` before editing this area.
Machine config compatibility is carried through `DOTFILES_HARDWARE_*`,
`DOTFILES_GIT_*`, and `DOTFILES_MANAGED_GIT_*` variables. When no machine file
matches, preserve caller-provided Git identity and signing fallbacks.

Git has two owners:

- Shared defaults: `tools/git/config/.config/git/local.gitconfig`, stowed to
  `~/.config/git/local.gitconfig`.
- Machine identity and signing: `~/.gitconfig`, managed by
  `tools/git/install.sh`.

Keep identity out of shared config. Preserve the ignored, local-only
`tools/git/config/.gitconfig`. Migration keeps the canonical include first,
moves existing regular XDG Git config and ignore files to timestamped backups,
backs up `~/.gitconfig` before filtering when it has unmanaged keys or includes
or lacks the canonical include, refuses non-managed `~/.gitconfig` or
`~/.config/git` symlinks, and preserves manual-migration errors instead of
writing through them.

Minimum Git-area validation:

```bash
bash -n install.sh machines/*.sh \
  tools/git/install.sh tools/git/migrate-config.sh tools/macos/install.sh
shellcheck install.sh machines/*.sh \
  tools/git/install.sh tools/git/migrate-config.sh tools/macos/install.sh
bash tools/git/tests/identity.sh
bash tools/git/tests/migrate-config.sh
git config --file tools/git/config/.config/git/local.gitconfig --list >/dev/null
```
