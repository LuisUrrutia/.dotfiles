# Agent Guide

This is a native mise setup repository. Installation targets fresh macOS arm64
and Ubuntu arm64/x86_64; portable configuration stays separate from OS packages
and services.
Read `CONTEXT.md` for ownership and `README.md` for current commands.

## Source map

- `install.sh`, `bootstrap/`: official mise download and machine enrollment.
- `mise.toml`: repository verification toolchain and tasks.
- `config.toml`, `miserc.toml`: shared active setup policy and platform selection.
- `conf.d/<capability>/`: native manifests, real source files, and setup tasks.
- `conf.d/setup/`: preservation, preferences, serial application, and maintenance.
- `tasks/`: global operational task entrypoints.
- `machines/`: tracked public enrollment records and optional local agent guidance.
- `tests/`: four behavioral integration areas, schemas, and parser/static checks.
- `.github/workflows/ci.yml`: the same verification command on macOS and Ubuntu.
- `plans/mise-migration*.md`, `plans/mise-compatibility.md`: agreed scope and evidence.
- `conf.d/hammerspoon/AGENTS.md`: verified macOS automation constraints.

Read implementations before changing them. `.editorconfig` owns formatting.

## Ownership and safety

The public checkout seeds only missing files. Regular active sources under
`~/.config/mise` belong to private mise history. Keep the public checkout outside
history's write ownership. Public import/promotion needs an explicit file diff;
never mirror the complete active tree back into this repository.

Use native mise packages, file deployment, edits, history, encryption, and
services. Small adapters own the remaining preservation and application edges;
do not rebuild a package manager or a Git synchronization engine. Keep one owner
per command and managed file. Required-resource skips are failures.

Never execute a real bootstrap, package update, preferences import, or service
registration on the operator's machine merely to verify repository changes.
Use isolated homes and local origins. Fresh-Mac and GUI acceptance requires an
explicitly supplied disposable environment or authorized setup run.

Preserve unknown regular files and foreign links, including redirected parents.
An app replacing a link is drift: inspect it and require explicit capture or
discard, preserving a backup. Do not force native apply through the guard or run
global prune. Unselecting a module does not authorize deleting its app/data.

Do not add a legacy-state migrator, Stow conversion, Homebrew uninstaller, or
role profiles. Native brew recipes may use `/opt/homebrew`; never invoke `brew`.

## Machine and private state

Keep `machines/*.toml` tracked. Local enrollment files, identities, credentials,
licenses, logs, caches, and runtime databases stay outside the public payload.
Every plist backup and private companion config must be encrypted from its first
history save. Capture only reviewed keys/files. Do not link live CFPreferences
plists, overwrite a pending incoming snapshot, or stop active apps to restore.

Git shared defaults and native identity blocks have separate owners. Preserve
unrelated keys and the unknown-machine fallback. Keep scoped account and signing
checks in real repositories and worktrees. Git authorship does not establish the
active SSH or `gh` identity.

Both sync modes keep native history in manual network mode. Only the serialized
`sync` task applies incoming setup; the watcher owns local autosave. Local mode
and app selection never travel. Update, apply, capture, and exchange share a lock.
Record successful application and maintenance stamps only after success.

## Fish and agent instructions

Human-only Fish behavior follows an interactive guard. Preserve caller-provided
environment values with default-only assignments. Keep one mise activation owner
and use interactive abbreviations instead of changing raw subprocess behavior.
Keep Mac-only startup and function sources in the Mac fragment.

`conf.d/ai/AGENTS.md` is the public seed for common agent instructions. Its active
source is `~/.config/mise/conf.d/ai/AGENTS.md`. The managed links are
`~/.agents/AGENTS.md` to that source and `~/.codex/AGENTS.md` to the common link.
Claude imports it. Preserve foreign destinations and a nonempty Codex override;
local guidance links only to the current machine's tracked `.agents.md` source.

## Verification and completion

Run `mise run verify` in this checkout. It compiles/parses sources, runs native
isolated deployment and history tests, checks shell/Fish/Lua/config/schema/workflow
syntax, scans the public payload for secrets, and checks the diff. There is no
separate app build. For a narrow iteration, run the corresponding unittest or
parser, then the full command before completion.

Keep tests proportional: four integration areas protect preservation, identities,
encrypted recovery, and exchange/application. Do not retain tests for deleted
installers or replicate upstream mise internals. No Stow or Brewfile tests remain.
Record exact commands and outcomes. Distinguish successful repository verification
from outstanding package, GUI, App Store, privacy, and real app restore acceptance.
