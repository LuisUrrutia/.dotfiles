# Dotfiles with mise

A fresh macOS or Ubuntu setup managed by mise: software, shell, application
configuration, preferences, and private setup history. Homebrew and Stow executables are not
part of the setup. Native `brew:` recipes use `/opt/homebrew` on macOS and
`/home/linuxbrew/.linuxbrew` on Linux because their binaries expect those paths.

Supported targets are **macOS on Apple Silicon** and **Ubuntu on arm64 or x86_64**.
Shared configuration and runtimes load on both. Ubuntu uses native `apt:` recipes
for system packages and mise tools for development CLIs. CocoaPods and MozJPEG
use native `brew:` recipes on both platforms; mise installs their Linux bottles
without installing Homebrew. MozJPEG's commands take precedence over the distro's
libjpeg tools. macOS applications and preferences load only on macOS. Arch still
needs its own package declarations.

All portable tools in `conf.d/cli` have Linux declarations, including jq, eza,
fzf and zoxide. Only remindctl (Apple Reminders), mas (Mac App Store) and Mole
(macOS maintenance) remain exclusive to macOS.

`conf.d/dev` provides Yaak, dive, adb and fastboot on both platforms; Apparency
requires macOS. On Ubuntu, mise's GitHub backend installs the official Yaak
AppImage for the machine's architecture, with the three-day release cooldown.
Native apt declarations provide FUSE, EGL and GLES, and a native dotfile template
adds its desktop launcher. See the
[Linux acceptance evidence](plans/mise-compatibility.md#dev-and-ethereum-on-linux)
for the graphical testing limits.

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
  audio/                  independently selected apps and preference schemas
  ethereum/               Geth, Foundry and Solidity on macOS and Linux
  languages/              language packages, including Lua and LuaRocks
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

## Start on a fresh machine

Start after a fresh OS installation. Setup does not migrate an existing
installation or uninstall Homebrew.

1. On macOS, grant the terminal Full Disk Access and install Apple's Command
   Line Tools. On Ubuntu, use your normal login account with sudo access; the
   installer provisions curl, Git and CA certificates when missing. Run `sudo -v`
   in your terminal before full setup. Commands fail rather than wait for input.
2. Clone the public setup over HTTPS; no GitHub account is required:
   `git clone https://github.com/LuisUrrutia/.dotfiles.git ~/.dotfiles`.
   On a minimal Ubuntu image without Git or curl, first run
   `sudo apt-get update && sudo apt-get install -y git curl ca-certificates`.
3. In the checkout, run `./install.sh --mise-only`. The installer downloads
   the latest stable official mise using `mise.run`, which selects the platform
   and verifies the release SHA-256. It keeps an equal or newer installed binary.
   Installation is staged before replacing the executable. `min_version` in
   the manifests is a compatibility floor for structured edits, not a pin.
4. Prepare a dedicated age identity outside tracked state and a separate recovery
   identity. The official workflow is documented at
   https://mise.jdx.dev/dotfiles/encryption.html. Use
   `~/.local/bin/mise exec age -- age-keygen -o ~/.config/mise/age.txt` after
   creating that directory, and restrict the file to mode `0600`. Store the
   recovery identity in 1Password or offline, not in this checkout or history.
   Private Git authentication and age decryption are separate requirements.
5. Run `./install.sh --help` and select the enrollment inputs below. An existing
   machine record supplies public identity and hostname defaults. Unknown machines
   keep existing Git identity unless a record is supplied. Linux derives its ID
   from `/etc/machine-id`; use `--machine` to retain an ID after reinstalling.

For initial enrollment, pass `--recipient` once for each public machine key and
once for the independent recovery key, plus `--origin` with the private Git URL.
HTTPS and SSH are supported. For HTTPS, authorize a Git credential helper before
enrollment; keep credentials out of the URL and tracked files. Public dependency
downloads do not require that authentication. Existing SSH origins stay unchanged.
Pass `--sync manual` or `--sync automatic`. Use `--record` for a local enrollment
TOML and `--apps` for comma-separated optional module names. `--seed-only`
prepares missing sources and local inputs without applying the setup. It is
useful for reviewing or editing them before installation.

For another machine, recover a matching age identity and private Git access first,
then use `./install.sh --adopt <private-Git-origin>` with its local enrollment inputs.
Adoption restores history before applying resources. A missing identity stops
recovery. Mac hardware keeps its stable ID across reinstalls. On Ubuntu, retain the old
`--machine` value when you need the same enrollment after reinstalling.

`./install.sh --dry-run` is a non-mutating first-use outline. After enrollment,
`mise -C ~ bootstrap --dry-run` previews the effective native resources; it may
need network metadata. Neither command proves successful package installation.

On both platforms, the login-shell hook uses existing sudo authorization to
register the declared shell and change the account without another password prompt.
It reads native mise's declaration and leaves the final status check to mise.

Ubuntu needs a working systemd user session for local history saves and
automatic exchange. A native systemd timer invokes the same serialized `sync`
task every five minutes; macOS uses a native LaunchAgent. Containers without a
user manager can test packages and files but cannot pass full setup acceptance.

Public downloads normally need no GitHub account. If GitHub returns `403` after
its anonymous API quota is exhausted, authenticate for downloads or retry after
the reported reset. Mise supports an existing `gh` login or a token supplied
only in the process environment; never put one in a tracked file. See
https://mise.jdx.dev/dev-tools/github-tokens.html.

On macOS, run the system-settings phase from the local console. Its firewall policy
disables automatic permission for signed applications; incoming services such
as SSH can require an explicit firewall decision before reconnecting.

Zed and IINA file associations are applied without confirmation dialogs. Setup
merges only the requested handlers into LaunchServices preferences, reloads the
current user's association service, and verifies the effective defaults in a
fresh process. Unrelated associations stay intact; an unchanged rerun does not
write preferences or reload the service. This uses an undocumented macOS storage
format, tested on macOS 27.0. If verification fails, setup stays pending and asks
you to sign out and back in before retrying; it never opens confirmation dialogs
as a fallback. See [the VM evidence](plans/mise-compatibility.md#silent-file-associations).

AutoFirma uses its interactive vendor installer because mise does not support
the cask's `installer manual:` artifact. `setup:autofirma` reads the current
version, download URL, SHA-256 and package filename from
https://formulae.brew.sh/api/cask/autofirma.json. It downloads that release and
checks its checksum and package signature before printing the command to open
it. Complete the installer and rerun `mise -C ~ run config apply`; setup remains
pending until its package receipt and application are present at that version
or newer. `update` checks the cask daily and prepares any new release through
the same task. No AutoFirma version or archive URL is pinned in this repository.

Third-party taps use mise's default GitHub metadata resolution. Public recipes,
font repositories, plugins, skills and the initial checkout use HTTPS. The shared
Git configuration preserves each URL's protocol instead of rewriting HTTPS to SSH.
Private setup history still requires authentication for its chosen transport.

IINA's module redirects its DMG download to the official GitHub release through
mise's `url_replacements`. The native cask still owns its version, checksum,
application and CLI installation, and self-update behavior.

Ghostty setup and maintenance first use the native cask's official download.
If that download fails, a small adapter looks up the **same DMG** in Nix's
content-addressed cache. It verifies the cache archive, the original cask's
SHA-256, and Ghostty's Apple Developer ID signature before filling mise's download
cache and retrying. It installs neither Nix nor Homebrew and needs no GitHub API
authentication. An unavailable mirror or failed verification leaves setup failed;
it never substitutes another version or overwrites a damaged existing download.
The cask continues to select releases and own installation and self-updates.

This recovery runs through `config apply`, initial bootstrap, and `update` for
the default macOS `latest` declaration. Direct `mise bootstrap packages apply`
calls bypass the adapter. Pins and conditional package overrides are left to
native mise. The download-cache layout is verified against mise 2026.10.7; see
[the Ghostty acceptance record](plans/mise-compatibility.md#ghostty-download-recovery).

## Release policy

The initial mise executable follows latest stable without a cooldown so that
bootstrap can use its current native features. Tool installs and routine updates
keep the three-day policy below.

Flexible mise tool requests select the newest matching release at least three
days old, within the declared channel (for example, Node LTS). The embedded npm
installer, Aube, uses the same three-day window for releases and new package
names. If no dependency version is old enough, installation fails instead of
silently accepting a younger release. npm, pnpm, and Yarn also use three days.
Bootstrap deploys the Aube configuration before installing tools.

`npm:@luisurrutia/bird` follows `latest` without a cooldown. Its own package is
exempt from reputation and trust-policy gates, and approved for build scripts
and non-registry sources. These named exemptions do not extend to third-party
dependencies. Native integrity and malicious-package checks still apply.
The existing Claude Code and Codex cooldown exemptions remain.

`2password` keeps the three-day release cooldown and has a named
`allow_low_downloads` exception. Aube groups download count, new package names,
and similar-name checks under this option; dependencies remain subject to them.

This is not an age guarantee for every installation source: exact pins and
lockfiles bypass mise's release filtering, and backends need release-date
metadata. Bootstrap casks and vendor installers have their own version rules.
See https://mise.jdx.dev/configuration/settings.html#minimum_release_age and
https://mise.jdx.dev/dev-tools/backends/npm.html.

## Select individual optional apps

Edit `~/.config/mise/miserc.local.toml`, for example:

```toml
env = ["busycal", "audio-hijack"]
```

Available choices: `audio-hijack`, `busycal`, `camo`, `displaylink`, `ethereum`,
`focusrite`, `loopback`, `obs`, `skhd`, `soundsource`, and `stellar-cli`.
`ethereum` includes Geth, Foundry and Solidity on macOS and Linux. The audio
apps live together in `conf.d/audio` and remain individually selectable.
On Linux, mise's Go backend builds the Geth command suite using the shared Go
toolchain and build prerequisites. Foundry and Solidity use native brew recipes.
OBS includes its scene-switcher plugin. There are no role profiles.
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

Public changes are a separate reviewable operation. Fetch this checkout, compare
only the intended relative file with the active source using
`git diff --no-index`, merge the selected changes, and run `config apply`.
Enrollment only fills missing files; it never merges an updated public version
over your active edits. To promote an active edit, compare and copy that specific
public source file back to this checkout, review `git diff`, and run `mise run
verify`. Never copy the whole active tree: it includes private snapshots and
local enrollment data. The pre-commit hook scans staged content for secrets.

## Native features and adapters

Mise owns package installation, links, file edits, defaults, services, encryption,
history and Git exchange. The remaining setup code handles behavior those native
operations do not provide: preserving foreign links and locally edited copies,
capturing only shared keys from app-written files, exporting selected macOS
preferences, and applying newly received package declarations. It does not encrypt
files or implement Git merging. Maintenance also covers external plugin managers.

The native capability audit, including the limits checked in mise's source, is in
[the compatibility record](plans/mise-compatibility.md#native-capability-audit).

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

CI runs the same command on macOS and Ubuntu. macOS also typechecks the Swift
helpers that use Apple frameworks. The suite uses real mise/Git with temporary
homes and local bare origins. It covers file preservation, Git identities/worktrees,
encrypted preferences, and manual/automatic exchange. A focused Ghostty recovery check rejects altered DMGs
and malformed cache archives. Syntax, format/schema, workflow, secret, and shell
smoke checks complement those four areas. There is no application build target;
compilation/parsing and native deployment are the build-equivalent checks.

The current evidence and outstanding acceptance steps are in
[the compatibility record](plans/mise-compatibility.md) and
[POST_INSTALL.md](POST_INSTALL.md). No live machine has been converted by this
repository rewrite. Cask replacement can still reset macOS privacy grants;
self-update handling does not make TCC portable.
