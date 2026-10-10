# Dotfiles with mise

A fresh macOS setup managed by mise: software, shell, application configuration,
preferences, and private setup history. Homebrew and Stow executables are not
part of the setup. Native `brew:` and `brew-cask:` recipes still use
`/opt/homebrew`.

The first target is **macOS on Apple Silicon**. Portable configuration and runtime
modules are separate from macOS resources. Ubuntu/Arch installation, packages,
and scheduling remain future work.

## Layout

```text
install.sh                first-use prerequisites and official mise installation
bootstrap/                verified download and machine enrollment
mise.toml                 repository verification tools and tasks
config.toml               active setup policy
miserc.toml               automatic platform environments
conf.d/
  fish/                   mise declarations, config.fish, functions, completions
  git/                    defaults and identity template
  macos/                  native defaults, LaunchAgents, system settings
  <capability>/           packages, source files, and any required setup task
  setup/                  preservation, preferences, synchronization, maintenance
tasks/                    config, preferences, sync, update
machines/                 public enrollment records and optional agent guidance
tests/                    four behavioral integration areas and real parsers
plans/                    decisions, source inventory, compatibility evidence
```

Enrollment copies missing public files into `~/.config/mise` as regular files.
That active tree is then owned by the private mise history, independently of the
public checkout. Application links point into the active tree. Edit it on any
machine; shared source files, installation declarations, plugin manifests, and
setup tasks travel together.

`config.local.toml` contains machine identity, Git inputs, sync mode, and the
private origin. `miserc.local.toml` selects optional apps. These files and
`age.txt` do not travel in history. Public `machines/*.toml` records are tracked;
credentials are not.

## Start on a fresh Mac

This replaces the old setup after reinstalling macOS. It does not migrate an
existing installation or uninstall Homebrew.

1. Grant the terminal Full Disk Access. Install Apple's Command Line Tools and
   validate sudo when the installer requests them, then rerun it. Automation
   fails on an unavailable prerequisite instead of waiting for input.
2. Prepare SSH access to GitHub and the private setup repository. Clone with SSH:
   `git clone git@github.com:LuisUrrutia/.dotfiles.git ~/.dotfiles`.
3. In the checkout, run `./install.sh --mise-only`. The installer downloads
   official mise **2026.10.7** and verifies its pinned SHA-256. Newer compatible
   installations are kept. This version is required for structured file edits.
4. Prepare a dedicated age identity outside tracked state and a separate recovery
   identity. The official workflow is documented at
   https://mise.jdx.dev/dotfiles/encryption.html. Use
   `~/.local/bin/mise exec age -- age-keygen -o ~/.config/mise/age.txt` after
   creating that directory, and restrict the file to mode `0600`. Store the
   recovery identity in 1Password or offline, not in this checkout or history.
   SSH Git authentication and age decryption are separate requirements.
5. Run `./install.sh --help` and select the enrollment inputs below. An existing
   machine record supplies public identity and hostname defaults. Unknown Macs
   keep existing Git identity unless a record is supplied.

For initial enrollment, pass `--recipient` once for each public machine key and
once for the independent recovery key, plus `--origin` with the private SSH URL.
Pass `--sync manual` or `--sync automatic`. Use `--record` for a local enrollment
TOML and `--apps` for comma-separated optional module names. `--seed-only`
prepares missing sources and local inputs without applying the setup. It is
useful for reviewing or editing them before installation.

For another machine, recover a matching age identity and SSH access first, then
use `./install.sh --adopt <private-SSH-origin>` with its local enrollment inputs.
Adoption restores history before applying resources. A missing identity stops
recovery. A reinstall of the same hardware keeps its stable machine ID so its
hardware-bound preferences can be restored.

`./install.sh --dry-run` is a non-mutating first-use outline. After enrollment,
`mise -C ~ bootstrap --dry-run` previews the effective native resources; it may
need network metadata. Neither command proves successful package installation.

## Select individual optional apps

Edit `~/.config/mise/miserc.local.toml`, for example:

```toml
env = ["busycal", "audio-hijack"]
```

Available choices: `audio-hijack`, `busycal`, `camo`, `displaylink`, `ethereum`,
`focusrite`, `foundry`, `loopback`, `obs`, `skhd`, `solidity`, `soundsource`, and
`stellar-cli`. OBS includes its scene-switcher plugin. There are no role profiles.
The common macOS setup includes the former cloud, dev, formatters, image, and
languages categories. The work Mac can leave the optional list empty.

Removing a selection stops managing it; it does not delete application data or
uninstall packages. Review native `mise bootstrap unapply <module> --dry-run`
before explicit removal. No task runs global package pruning.

## Configure Git identities

Public records and local `--record` inputs use this shape:

```toml
[git.default]
name = "Example User"
email = "personal@example.invalid"

[git.accounts.work]
name = "Example User"
email = "work@example.invalid"
directories = ["~/Work"]
# signing_key = "~/.ssh/work_ed25519.pub"
```

Use a default alone for one identity; omit it and declare two accounts for a
work machine; combine a default and scoped accounts for an agent machine.
Directory conditions also cover Git worktrees. Signing is enabled only when a
signing key is supplied. An unsigned scoped account disables inherited signing.
The managed Git block and first shared include preserve unrelated existing keys.
Identity inputs are rendered into `config.local.toml`; later edits belong there.
Git authorship does not select an SSH account or the authenticated `gh` actor.

## Daily commands

Run these from HOME, or retain `-C ~` to avoid another project's mise config:

| Command | Effect |
| --- | --- |
| `mise -C ~ run config status` | Inspect native file and history state |
| `mise -C ~ run config diff` | Compare declared and live configuration |
| `mise -C ~ run config apply` | Apply the effective setup after preservation checks |
| `mise -C ~ run sync` | Capture, save, exchange, pull, apply changed setup, restore preferences |
| `mise -C ~ run preferences capture` | Capture allowlisted application settings into encrypted history |
| `mise -C ~ run preferences restore` | Retry pending restores after closing apps |
| `mise -C ~ run update` | Update declared software and plugins, respecting daily/weekly gates |
| `mise -C ~ run update --ignore-schedule` | Run all maintenance gates now |

Fish provides `upd` and `backup` shortcuts. For new software, add the declaration
to the owning active module **before** running `config apply`; downloaded
binaries and application state are not synchronized.

Both machine modes keep native `history.sync = "manual"`. The native watcher
saves locally. Only automatic machines install a five-minute LaunchAgent that
runs the serial `sync` task. Manual machines exchange on request. Automatic
mode runs received setup code and installs eligible declared software as the
local user. A lock prevents overlapping apply/update/sync operations. Failed
application remains pending, retries with backoff, and stops automatic retries
after three attempts for the same inputs. Repair the prerequisite and run
`config apply` explicitly to retry.

A configuration-only change does not require sudo again for unchanged privileged
macOS policy. New privileged software, App Store login, GUI permissions, or a
changed system policy may still require a manual run. Logs are under
`~/.local/state/mise/dotfiles/`; `apply.json` records pending and applied inputs.

## Preserve and resolve changes

If an app replaces a managed link with a regular file, setup refuses to overwrite
it. Inspect the difference, then run `config capture <managed-file>` to retain
the live edit in its source, or `config discard <managed-file>` to deploy the
source. Both preserve the previous target under local state. Directories,
foreign parents, and template outputs need individual review.

For Codex and Claude, native structured edits own only the keys in their shared
source files. `sync`, `config apply`, and `update` capture changes to those keys
back into the source before application. Unrelated application keys remain local.
Concurrent source/target edits stop for an explicit capture/discard decision.
Removing a shared key needs review: removing it from the source relinquishes
ownership; native merge does not delete it on other machines. Add new shared
settings to the source rather than copying the whole application config.

Native history conflicts stop application. Use `mise dot status`,
`mise dot conflicts <path>`, and an explicit `mise dot pull --keep-local <path>`
or `--take-remote <path>` decision. `mise dot recover` handles interrupted native
operations. `mise dot undo` reverses the last file operation; it does not promise
package downgrades. Keep ordinary exchange through `mise run sync` so a successful
pull is followed by setup application.

Public changes are a separate reviewable operation. Fetch this checkout over
SSH, compare only the intended relative file with the active source using
`git diff --no-index`, merge the selected changes, and run `config apply`.
Enrollment only fills missing files; it never merges an updated public version
over your active edits. To promote an active edit, compare and copy that specific
public source file back to this checkout, review `git diff`, and run `mise run
verify`. Never copy the whole active tree: it includes private snapshots and
local enrollment data. The pre-commit hook scans staged content for secrets.

## Encrypted application preferences

Thaw, LinearMouse, SuperCmd, SoundSource, Loopback, and Audio Hijack have explicit
allowlists. All plist snapshots and companion private JSON files are encrypted
before entering history. Preferences use `defaults export/import`; live
CFPreferences plists are never symlinked. Enrollment initializes an encrypted
policy marker before the first checkpoint, including when no app settings exist
yet. Public sources contain no plist backup.
Older commits of the public repository still contain the former Thaw plist;
this change does not rewrite that history.

SuperCmd's allowlisted preferences are shared. Display/device layouts and audio
routing use `private/preferences/machines/<stable-id>/`. They travel for recovery
but are restored only on that machine. Licenses, tokens, AI credentials,
recordings, clipboard databases, caches, and recent-item history are excluded.
Capture and restore validate owned key types, companion-file structure and
reviewed file-format versions. Empty preference resets are recorded explicitly.
New app major versions require a schema review. Close the app and its writers
before restoring; the task leaves active-app restores pending instead of killing
processes. Incoming snapshots are preserved until restore completes. If existing
live settings differ, review them and use `preferences accept <app>` to keep an
encrypted conflict backup before accepting the incoming snapshot.

This protects explicitly allowlisted settings. Real application reopen tests
remain part of fresh-Mac acceptance, not a claim made by a plist parser.

## Verify this repository

Install the verification tools with `mise install --yes` and
`mise bootstrap packages apply --yes`, then run `mise run verify` in this
checkout. These repository commands provision only the verification toolchain;
`config.toml` is the separate payload for the active global setup.

The suite uses real mise/Git with temporary homes and local bare origins. It
covers file preservation, Git identities/worktrees, encrypted preferences, and
manual/automatic exchange. Syntax, format/schema, workflow, secret, and shell
smoke checks complement those four areas. There is no application build target;
compilation/parsing and native deployment are the build-equivalent checks.

The current evidence and outstanding acceptance steps are in
[the compatibility record](plans/mise-compatibility.md) and
[POST_INSTALL.md](POST_INSTALL.md). No live machine has been converted by this
repository rewrite. Cask replacement can still reset macOS privacy grants;
self-update handling does not make TCC portable.
