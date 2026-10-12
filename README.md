# Dotfiles with mise

Software, Fish, application settings, and private configuration history for a
fresh **macOS Apple Silicon** or **Ubuntu arm64/x86_64** installation. Mise manages
the setup without Homebrew or Stow executables. Arch needs its own package declarations.

## Start on a fresh machine

Setup does not migrate an existing installation or uninstall Homebrew.

1. **Prepare the OS.** On macOS, grant the terminal Full Disk Access and install
   Apple's Command Line Tools. Enable FileVault and save its recovery key outside
   history. The installer enables immediate screen locking when needed, using
   macOS's own password prompt in the terminal. It does not ask again when the
   setting is already correct.
   On Ubuntu, use a normal login account with sudo;
   the installer adds missing curl, Git, and CA certificates. Setup requests
   administrator authorization when needed and refreshes it until installation
   ends. Initial enrollment can also ask for the Mac login password and age's
   recovery password through their hidden terminal prompts. Background maintenance
   and diagnostics never prompt.

   Run macOS system settings from the local console: the firewall policy disables
   automatic permission for signed apps, so incoming services such as SSH may need
   an explicit firewall decision before you reconnect. Ubuntu needs a working
   systemd user session for history saves and automatic sync. Containers without
   one can test packages and files, but cannot pass full setup acceptance.

2. **Clone the public setup.** No GitHub account is required. On a minimal Ubuntu
   image without Git or curl, first run
   `sudo apt-get update && sudo apt-get install -y git curl ca-certificates`.

   ```sh
   git clone https://github.com/LuisUrrutia/.dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ```

3. **Install mise.** Run `./install.sh --mise-only`. It downloads the latest stable
   official release through `mise.run`, selects the platform, and verifies SHA-256.
   It stages the replacement and keeps an equal or newer installed binary.
   The manifests' `min_version` is a compatibility floor for structured edits, not a pin.

4. **Prepare password recovery.** If this checkout already has
   `backups/recovery.age`, enrollment with `--recover` asks for its password.
   For the first machine, run `~/.local/bin/mise run backup init` from this checkout
   to create it. Age asks for the password in the terminal. The public repo holds
   the encrypted recovery key; the unlocked identity stays in
   `~/.config/mise/age.txt` with mode `0600`. No USB or password manager is needed
   to recover. Native mise uses the local identity for unattended history saves.

   Private Git authentication and age decryption are separate requirements.
   HTTPS and SSH are supported; authorize a credential helper before using HTTPS.
   Keep credentials out of URLs and tracked files. Existing SSH origins stay unchanged.

5. **Enroll the machine.** Run `./install.sh --recover` with your history origin,
   sync mode, and any optional settings below. Recovery stages the public backups
   for this machine before bootstrap restores eligible app preferences.

   | Option                                | Purpose                                                                    |
   | ------------------------------------- | -------------------------------------------------------------------------- |
   | `--origin`                            | Private history Git URL                                                    |
   | `--recipient`                         | Repeat for each public machine key and the independent recovery key        |
   | `--recover`                           | Unlock the public recovery key, configure its recipient, and stage backups |
   | `--sync manual` or `--sync automatic` | Exchange on request or every five minutes                                  |
   | `--record`                            | Local enrollment TOML, including Git identities                            |
   | `--apps`                              | Comma-separated optional module names                                      |
   | `--machine`                           | Retain a machine ID after reinstalling                                     |
   | `--seed-only`                         | Prepare missing sources and local inputs for review without applying       |

Existing machine records provide public identity and hostname defaults. Unknown
machines keep their existing Git identity unless you supply a record. Mac hardware
IDs survive reinstalls; Linux derives its ID from `/etc/machine-id`. Retain the old
`--machine` value to recover the same Ubuntu enrollment.

To add another machine from the latest private history, run
`~/.local/bin/mise run backup unlock`, prepare private Git access, then run
`./install.sh --adopt <private-Git-origin>` with its local enrollment inputs.
Adoption restores history before applying resources; a missing identity stops recovery.

For a preview, use `./install.sh --dry-run` before enrollment or
`mise -C ~ bootstrap --dry-run` afterward. The first changes nothing; the second
may need network metadata. Neither proves that packages will install successfully.

Mise uses its native `jobs` setting (eight by default) for concurrent downloads,
tool installs, repository checkouts, and independent setup tasks. App placement
and dependent phases keep their required order. To change the limit for one run,
use `MISE_JOBS=4 ./install.sh --recover`.

## Daily commands

Keep `-C ~` to avoid loading another project's mise config, or run from HOME.

| Command                                  | Effect                                                                      |
| ---------------------------------------- | --------------------------------------------------------------------------- |
| `mise -C ~ doctor project`               | Check macOS FileVault and immediate screen-lock requirements                |
| `mise -C ~ run config status`            | Inspect file and history state                                              |
| `mise -C ~ run config diff`              | Compare declared and live configuration                                     |
| `mise -C ~ run config apply`             | Check preservation and prerequisites, then apply setup                      |
| `mise -C ~ run sync`                     | Capture, save, exchange, pull, apply changed setup, and restore preferences |
| `mise -C ~ run preferences capture`      | Save allowlisted app settings in encrypted history                          |
| `mise -C ~ run preferences restore`      | Retry pending restores after closing apps                                   |
| `mise -C ~ run update`                   | Update software and plugins on the daily/weekly schedule                    |
| `mise -C ~ run update --ignore-schedule` | Run all maintenance gates now                                               |

Fish also provides `upd` and `backup`. To install software, add its declaration to
the owning module in `~/.config/mise/conf.d` **before** running `config apply`.
Downloaded binaries and application state do not sync.

Personal skills stay in the editable checkout at `~/Projects/LuisUrrutia/skills`.
Mise clones `https://github.com/LuisUrrutia/skills.git` without GitHub authentication;
`skills:link` calls the Fish `skill-link` function for every skill in that checkout,
linking it into both `~/.agents/skills` (Codex) and `~/.claude/skills`.
`update` refreshes the repository and links newly added skills. Local edits stay
in the checkout, and mise refuses to update a dirty repository.
Third-party skills use the skills CLI with both agents selected.

## Configuration and sync

Enrollment copies only missing public files into `~/.config/mise` as regular files.
Edit this active tree: private mise history owns it, and application links point
here. Shared sources, installation declarations, plugin manifests, and setup tasks
travel together. The public checkout remains separate.

A full retry repairs the previously shipped terminal handling, HTTPS downloads,
public skills clone URL, and, on macOS, the screen-lock check.
It prints a short confirmation for each repair.
Custom checks and other active settings are preserved.
After an interruption, rerun the same installer command. It lets mise recover
unfinished history operations before preparing or applying setup, including on
previously enrolled machines. Recovery stops if a file was edited afterward;
it preserves the edit and reports the affected path for review.

Machine identity, Git inputs, sync mode, and the private origin live in
`config.local.toml`; optional apps live in `miserc.local.toml`. These files and
`age.txt` stay local. Public `machines/*.toml` records are tracked; credentials are not.

Both sync modes use native `history.sync = "manual"`; the watcher saves locally.
History commits identify the saving machine as `mise@<hostname>`.
Manual machines exchange on request. A native macOS LaunchAgent or Ubuntu systemd
timer dispatches automatic sync every five minutes. The worker runs in a separate
OS job so replacing the scheduler cannot interrupt application.
Automatic sync executes received setup code and installs eligible software as
the local user. A lock prevents overlapping apply, update, and sync operations.

Failed application stays pending, retries with backoff, and stops automatic retries
after three attempts with the same inputs. Fix the prerequisite and run
`config apply` to retry. Logs and `apply.json` (pending/applied inputs) live under
`~/.local/state/mise/dotfiles/`. Ubuntu worker output is also available through
`journalctl --user -u dotfiles-sync-worker.service`.

Configuration-only changes do not need sudo again for unchanged privileged macOS
policy. New privileged software, App Store login, GUI permissions, or changed
system policy may still need a manual run.

<details>
<summary>Resolve local changes, history conflicts, and public updates</summary>

If an app replaces a managed link with a regular file, setup stops rather than
overwrite it. Inspect the diff, then use `config capture <managed-file>` to keep
the live edit in its source, or `config discard <managed-file>` to deploy the source.
Both back up the previous target under local state. Directories, foreign parents,
and template outputs need individual review.

For Codex and Claude, native structured edits own only keys declared in their
shared sources. `sync`, `config apply`, and `update` capture changes to those keys
before applying; unrelated keys stay local. Concurrent source/target edits require
an explicit capture/discard decision. Add shared settings to the source rather
than copying a whole app config. Removing a source key relinquishes ownership;
native merge does not delete it on other machines, so review removals.

Native history conflicts stop application. Inspect with `mise dot status` and
`mise dot conflicts <path>`, then choose `mise dot pull --keep-local <path>` or
`--take-remote <path>`. `mise dot recover` handles interrupted operations;
`mise dot undo` reverses the last file operation, without promising package
downgrades. Use `mise run sync` for ordinary exchange so setup is applied after a pull.

To import a public update, fetch this checkout, compare the intended relative file
with its active source using `git diff --no-index`, merge the selected changes,
then run `config apply`. Enrollment fills missing files; it never merges public
updates over active edits.

To promote an active edit, compare and copy that specific public source file back
to this checkout, review `git diff`, and run `mise run verify`. Never copy the whole
active tree: it contains private snapshots and local enrollment data. The
pre-commit hook scans staged content for secrets.

</details>

<details>
<summary>Encrypted application preferences</summary>

Before formatting an existing Mac, run these commands **from this checkout**:

```sh
./install.sh --mise-only
~/.local/bin/mise run backup init
~/.local/bin/mise run backup capture
~/.local/bin/mise run backup verify
```

Run `init` only once. On another machine, use `backup unlock` instead. `capture`
reads every supported installed app, including optional audio apps, without
enrolling the machine, replacing old links, changing preferences, or running
package installers. It can read an existing companion-file symlink within HOME.
`verify` asks for the recovery password and checks every archive without using
the local identity. It does not import preferences.

Review, commit, and push `backups/` before erasing the old installation:

```text
backups/
  recovery.age                  password-encrypted recovery identity
  recovery.pub                  public age recipient
  preferences/
    shared.plist.age            portable app settings
    <machine-id>.plist.age      settings for that machine
```

Only ciphertext and the public recipient enter this directory. Use a strong,
unique recovery password: these encrypted files will be publicly downloadable.
The same unlocked identity permits unattended saves on enrolled machines.
Public exports use the official age CLI; private operational history still uses
native mise encryption and sync. New macOS installations also run
`backup capture --daily` through a native mise LaunchAgent, in both sync modes.
It checks at login and hourly, captures once per local calendar day, and retries
failed or busy runs at the next check. Manual `backup capture` always runs.
The unlocked local identity permits these captures without a password prompt.
Captures list apps and files; preference keys and values stay hidden.

Enrollment stores the checkout path in local `vars.dotfiles_repository`. Keep
that checkout available; if you move it, update the variable and run
`mise -C ~ run config apply`. Logs are `backup.log` and `backup.err.log` under
`~/.local/state/mise/dotfiles/`; `public-backup.json` records the last successful
capture. The current preference catalog is macOS-only, so Ubuntu has no public
preference capture schedule. Review, commit, and push the changed ciphertext to
publish it; neither the daily capture nor ordinary history sync publishes this
checkout.

After reinstalling, clone the repo and run `./install.sh --recover` with the
wanted optional apps. On Ubuntu, retain the old `--machine` ID if needed.
Recovery preserves an existing differing snapshot; resolve that conflict before
retrying. It never applies another machine's hardware-bound settings.

Thaw, LinearMouse, SuperCmd, SoundSource, Loopback, and Audio Hijack have explicit
allowlists. OBS also captures general settings, profiles, scene collections, and
INI/JSON plugin settings from `~/Library/Application Support/obs-studio`, including
streaming credentials and WebSocket passwords. The encrypted `obs-studio.plist`
snapshot preserves their relative paths and original contents. Capture lists the
included filenames without showing their values.

OBS snapshots restore only to the same machine ID, with OBS closed. Referenced
images, videos, fonts, and scripts are not bundled; preserve those files separately.
Browser cookies, logs, caches, recordings, and plugin binaries are excluded.

All plist snapshots and companion private configuration files are encrypted
before entering history. Enrollment creates an encrypted policy marker before
the first checkpoint, even when no app settings exist. Older public commits still
contain the former plaintext Thaw plist; encryption does not rewrite that history.

Preferences use `defaults export/import`; live CFPreferences plists are never
symlinked. SuperCmd's allowlisted settings are shared. Display/device layouts and
audio routing use `private/preferences/machines/<stable-id>/`: they travel for
recovery but restore only on that machine. Outside the explicit OBS credential
exception, licenses, tokens, AI credentials,
recordings, clipboard databases, caches, and recent-item history are excluded.

Capture and restore validate owned key types, companion-file structure, and
reviewed format versions. Empty resets are recorded explicitly; new app major
versions need a schema review. Close the app and its writers before restoring.
Active-app restores stay pending; the task never kills processes. Incoming
snapshots are preserved until restore completes. If live settings differ, review
them and use `preferences accept <app>` to save an encrypted conflict backup
before accepting the incoming snapshot.

Only allowlisted settings are protected. Real app reopen tests remain part of
fresh-Mac acceptance; passing a plist parser does not establish that they work.

</details>

## Select individual optional apps

Edit `~/.config/mise/miserc.local.toml`, for example:

```toml
env = ["busycal", "audio-hijack"]
```

Choices: `audio-hijack`, `busycal`, `camo`, `displaylink`, `ethereum`, `focusrite`,
`loopback`, `obs`, `openclaw`, `skhd`, `soundsource`, and `stellar-cli`.
Audio apps share `conf.d/audio` but remain individually selectable. `ethereum`
groups Geth, Foundry, and Solidity in `conf.d/blockchain`, alongside the independent
`stellar-cli` selection. OBS includes its scene-switcher plugin.

`openclaw` enables the native macOS `openclaw-sshfs` LaunchAgent. It needs a working
Tailscale connection, SSH host alias, macFUSE, and SSHFS; `openclaw-mount status`
checks the mount. To stop automatic mounting, remove the selection and run
`mise -C ~ bootstrap services remove openclaw-sshfs --yes`. The mount and its data
remain unchanged.

There are no role profiles. The common macOS setup includes the former cloud,
dev, formatters, image, and languages categories; a work Mac can leave the optional
list empty. Removing a selection stops management without uninstalling packages
or deleting app data. Review `mise bootstrap unapply <module> --dry-run` before
explicit removal. No task runs global package pruning.

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

Use a default for one identity, two scoped accounts without a default for a work
machine, or a default plus scoped accounts for an agent machine. Directory rules
also cover worktrees. Signing requires a signing key; unsigned scoped accounts
disable inherited signing. The managed block and first shared include preserve
unrelated Git keys. Authorship does not select an SSH account or authenticated `gh` actor.

<details>
<summary>Edit enrolled identities and native templates</summary>

Enrollment stores identity data in `config.local.toml` variables and registers
each account as a native template for mise to render.
`conf.d/git/identity.gitconfig.tera` renders the default and `includeIf` blocks.
`conf.d/git/account.gitconfig.tera` renders every scoped account and its signing
policy, using the native `bootstrap.files` `target` variable to select the account:

```toml
[bootstrap.files."~/.config/git/account-work.gitconfig"]
source = "conf.d/git/account.gitconfig.tera"
template = true
mode = "0600"
```

Edit `vars.git_name`, `vars.git_email`, and `vars.git_signing_key` for the default.
For the example account, edit `vars.git_account_work_name`,
`vars.git_account_work_email`, `vars.git_account_work_signing_key`, and
`vars.git_account_work_directories` (one absolute path per line).
`vars.git_accounts` lists account names separated by spaces. To add an account
after enrollment, add its name, variables, and a file declaration like the one above.
`config apply` checks account files for unowned content or drift before writing them.

</details>

## Platform and package reference

<details>
<summary>Linux packages, Fish, and Rust</summary>

`.NET` installs the 10.x SDK and the current supported LTS SDK. Bootstrap and
`update` refresh the LTS alias from Microsoft's release metadata, excluding
previews and releases younger than three days. The alias is stored locally;
ordinary mise commands need no network lookup. Both requests currently select
.NET 10. A later LTS is added alongside 10 on the next successful setup or update.

Shared configuration and runtimes load on both platforms; macOS apps and
preferences load only on macOS. Ubuntu uses native `apt:` system packages and
mise development CLIs. Native `brew:` binaries expect `/opt/homebrew` on macOS
and `/home/linuxbrew/.linuxbrew` on Linux; mise uses these paths without installing
Homebrew. MozJPEG uses this backend on both platforms, including a Linux bottle,
and its commands take precedence over distro libjpeg tools.

On macOS, a native pre-packages hook installs mise-managed Ruby before evaluating
third-party casks such as SuperCmd. Ruby follows the three-day release cooldown.

`conf.d/cli` includes Linux jq, eza, fzf, and zoxide. CocoaPods is macOS-only by
choice. remindctl (Apple Reminders), mas (Mac App Store), and Mole (macOS maintenance)
also remain macOS-only. `conf.d/dev` supplies Yaak, dive, adb, and fastboot on both
platforms; Apparency requires macOS. On Ubuntu, the GitHub backend installs the
official Yaak AppImage for the machine's architecture with the three-day cooldown.
Native apt declarations supply FUSE, EGL, and GLES; a dotfile template adds its
desktop launcher. See [Linux graphical testing limits](plans/mise-compatibility.md#dev-and-ethereum-on-linux).

Geth, Foundry, and Solidity support both platforms. On Linux, the Go backend builds
the Geth command suite using the shared Go toolchain and build prerequisites;
Foundry and Solidity use native brew recipes.

Fish uses native brew recipes on both platforms to support current `fzf.fish`
bindings. It is the login shell, with one mise activation owner in `conf.d/fish`
and no Bash or Zsh activation. The login-shell hook reads mise's
declaration and uses existing sudo authorization to register and change the shell
without another password prompt. Mise checks the final status.

Image helpers support ImageMagick 7 on macOS and Ubuntu's ImageMagick 6.
They resize and compress without macOS-only utilities.

Mise installs and updates Neovim's Rust, Lua, Tailwind, Astro, Docker, and TypeScript
language servers. Neovim enables them through `nvim-lspconfig` and resolves tools
through mise shims. Astro uses a workspace SDK when available, with mise's
TypeScript 6 as fallback; Astro does not support the TypeScript 7 SDK yet.

Native mise installs and updates Rust on both platforms, including Rustfmt and
Clippy in the default profile. Project `rust-toolchain.toml` files override the
global toolchain.

</details>

<details>
<summary>macOS desktop and system settings</summary>

Mise pins the full Dock order: Messages, optional BusyCal, Notes, Ghostty, Zed,
T3 Code (Nightly), Dia, App Store, and System Settings. Native defaults replace
dockutil; macOS keeps Finder and Trash. Edit `apps` in
`conf.d/macos/mise.macos.toml` and its BusyCal variant if selected. Each apply
restores the declared order.

User defaults and the screenshots directory are native declarations. Enrollment
stores the absolute screenshot path locally because mise defaults cannot render
templates. `system-settings.sh` handles privileged update preferences, firewall,
power commands, Library visibility, and remote-management settings.
Enrollment configures immediate screen locking before `mise doctor project`
checks it and FileVault. `--seed-only` does not change the lock setting.
Native defaults cannot write privileged system domains.

Thaw installs and updates only below macOS 27. A package hook checks the OS and
delegates to native casks because declarations cannot express that version range.
Upgrading macOS neither uninstalls Thaw nor erases its encrypted snapshots.

Zed and IINA associations apply without confirmation dialogs. Setup merges only
requested LaunchServices handlers, reloads the user's association service, and
verifies effective defaults in a fresh process. Unrelated associations remain;
unchanged reruns do not write or reload. The storage format is undocumented and
tested on macOS 27.0. Failed verification leaves setup pending and asks for sign-out
and sign-in before retrying; it never falls back to confirmation dialogs.
See [VM evidence](plans/mise-compatibility.md#silent-file-associations).

</details>

<details>
<summary>Downloads: GitHub, AutoFirma, IINA, and Ghostty</summary>

Public recipes, font repositories, plugins, skills, and the initial checkout use
HTTPS without private-history authentication. Third-party taps use mise's default
GitHub metadata resolution. Shared Git config preserves each URL's protocol.
Private history requires authentication for its chosen transport.

If GitHub returns `403` after exhausting its anonymous API quota, authenticate or
retry after the reported reset. Mise accepts an existing `gh` login or a token
in the process environment. Keep tokens out of tracked files.
See https://mise.jdx.dev/dev-tools/github-tokens.html.

**AutoFirma:** mise does not support the cask's `installer manual:` artifact.
The final bootstrap hook runs `autofirma` after the other setup tasks finish.
It reads the current version, URL, SHA-256, and package filename
from https://formulae.brew.sh/api/cask/autofirma.json, downloads it, verifies the
checksum and package signature, then opens the vendor installer when run from a
terminal. Complete its dialogs and close Installer; setup verifies the receipt
and app before continuing. Cancellation leaves setup pending. Background runs
prepare the package and report how to finish without opening a window. `update`
checks daily through the same task, after the other maintenance steps and the
history save; no version or archive URL is pinned.

**IINA:** native `url_replacements` redirect the DMG to the official GitHub release.
The cask owns the version, checksum, app/CLI installation, and self-update behavior.

**Ghostty:** mise manages the native `brew-cask:ghostty` package. The cask owns
downloads, checksum verification, app installation, and self-update handling.

</details>

<details>
<summary>Release policy and exceptions</summary>

The initial mise executable uses latest stable without a cooldown to support
current native features. Flexible tool requests and routine updates select the
newest matching release at least three days old within their channel, such as Node LTS.

Aube, the embedded npm installer, applies three days to releases and new package
names. If no dependency version qualifies, installation fails. Its configuration
is deployed before tools install. npm, pnpm, and Yarn also use three days.

- `npm:@luisurrutia/bird` uses `latest` without a cooldown. Its own package is exempt
  from reputation and trust-policy gates and approved for build scripts and
  non-registry sources. Dependencies get no such exemptions; native integrity and
  malicious-package checks still apply.
- Existing Claude Code and Codex cooldown exemptions remain.
- `2password` keeps the three-day cooldown but has a named `allow_low_downloads`
  exception. Aube groups download counts, new names, and similar-name checks under
  this option. Dependencies remain subject to them.

Exact pins and lockfiles bypass mise release filtering, backends need release-date
metadata, and casks/vendor installers have their own version rules. The cooldown
is therefore not a guarantee for every source.
See https://mise.jdx.dev/configuration/settings.html#minimum_release_age and
https://mise.jdx.dev/dev-tools/backends/npm.html.

</details>

## Repository layout and verification

```text
install.sh       prerequisites and official mise installation
bootstrap/       verified download and machine enrollment
mise.toml        repository verification tools and tasks
config.toml      active setup policy
miserc.toml      automatic platform environments
conf.d/          modules: native declarations, source files, required setup tasks
tasks/           config, preferences, sync, update
machines/        public enrollment records and optional agent guidance
tests/           four behavioral integration areas and real parsers
plans/           decisions, source inventory, compatibility evidence
```

In this checkout, install tools with `mise install --yes` and
`mise bootstrap packages apply --yes`, then run:

```sh
mise run verify
```

These commands provision only the verification toolchain; `config.toml` is the
separate active setup payload. `mise run format` formats sources and applies safe
Ruff fixes; `mise run lint` checks without edits. Verification includes lint and
format checks before integration tests, so CI rejects unformatted changes.

<details>
<summary>Module responsibilities and native mise boundaries</summary>

| Module        | Contents                                            |
| ------------- | --------------------------------------------------- |
| `fish/`       | Declarations, `config.fish`, functions, completions |
| `git/`        | Defaults and identity templates                     |
| `audio/`      | Independently selected apps and preference schemas  |
| `blockchain/` | Ethereum tools and optional Stellar CLI             |
| `dev/`        | Development apps, including Yaak and OrbStack       |
| `languages/`  | Runtimes, native mise Rust, and Lua packages        |
| `macos/`      | Defaults, LaunchAgents, system settings             |
| `media/`      | yt-dlp, IINA, optional OBS/Camo                     |
| `setup/`      | Preservation, preferences, sync, maintenance        |

Mise owns packages, links, file edits, defaults, services, history and its encryption,
and Git exchange. Adapters preserve foreign links and edited copies, capture
shared keys from app-written files, export selected macOS preferences, and apply
received package declarations. The public backup adapter delegates standalone
file encryption and password prompts to age. No adapter implements Git merging.
Maintenance also covers external plugin managers. For limits checked in
mise's source, see the [native capability audit](plans/mise-compatibility.md#native-capability-audit).

</details>

<details>
<summary>Checks, CI, and acceptance limits</summary>

| Sources                                                 | Lint / validation                                                | Formatter               |
| ------------------------------------------------------- | ---------------------------------------------------------------- | ----------------------- |
| Python                                                  | Ruff, compiler                                                   | Ruff                    |
| Bash, including extensionless scripts and task wrappers | ShellCheck, shfmt parser                                         | shfmt                   |
| Fish                                                    | Fish parser                                                      | fish_indent             |
| Lua, including Neovim and Hammerspoon                   | Luacheck, StyLua parser                                          | StyLua                  |
| TOML                                                    | Taplo, Python TOML parser                                        | Taplo                   |
| JSON / JSONC                                            | JSON / JSON5 parsers, applicable schemas                         | Prettier                |
| YAML and GitHub configuration                           | Prettier parser, actionlint, Dependabot schema, action SHA audit | Prettier                |
| Markdown                                                | markdownlint-cli2                                                | Prettier                |
| HTML, including embedded CSS and JavaScript             | Prettier parser                                                  | Prettier                |
| Swift (macOS job)                                       | swift-format lint, Swift typechecker                             | swift-format            |
| XML theme plists                                        | Python plist parser                                              | Python plist serializer |
| Git configuration                                       | Git config parser                                                | EditorConfig whitespace |
| Other text, app configuration, dictionaries, templates  | EditorConfig; deployment tests also exercise managed templates   | EditorConfig whitespace |

Checks cover tracked and new non-ignored files, including hidden files. Ignored
caches, local state, and binary icons are outside text formatting. App config
without a dedicated parser gets whitespace checks, not app validation. Lua keeps
four spaces for Hammerspoon and two for Neovim. Markdown preserves paragraph
wrapping, visible URLs, and heading-free prompts/templates.

Tools follow the latest-compatible policy and three-day cooldown. macOS supplies
`swift-format` through Apple's toolchain; Ubuntu leaves that helper to macOS CI.
CI runs the same verification on macOS 26 arm64 and Ubuntu 24.04 arm64/x86_64,
using the latest official mise with checksum verification and mise-installed tools.
macOS also typechecks helpers that use Apple frameworks.

Tests use real mise/Git, temporary homes, and local bare origins. Four areas cover
preservation, Git identities/worktrees, encrypted preferences, and manual/automatic
exchange. Native task validation checks this checkout and the isolated
active setup, including all optional modules. Syntax, format/schema, workflow,
secret, and shell smoke checks complete the suite. There is no app build target;
compilation/parsing and native deployment serve that purpose.

Dependabot updates SHA-pinned GitHub Actions weekly with a three-day cooldown,
grouping minor/patch releases and keeping majors separate. Mise maintenance owns
tool/package updates; Dependabot does not support those manifests.

</details>

See [compatibility evidence](plans/mise-compatibility.md) and
[POST_INSTALL.md](POST_INSTALL.md) for outstanding acceptance steps. The repository
rewrite has not converted a live machine. Cask replacement can still reset macOS privacy
grants; self-update handling does not make TCC permissions portable.
