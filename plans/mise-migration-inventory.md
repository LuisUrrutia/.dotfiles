# Mise-native macOS setup: scope inventory

Baseline: `0c2f8fe3739a1e16e80d07d476453bf119db55dc`, inspected 2026-10-10.

This inventories source declarations for a fresh macOS setup, not existing
machine state or proof of mise package support. D13 cancels in-place migration.
M0 verifies fresh installation and updates for retained packages; no installed
Homebrew inventory or transfer ledger is required.

See the [plan](mise-migration.md) and [decision
map](mise-migration-decisions.md).

## Package declarations

The current source has 126 core entries, 40 optional-profile entries, and 17
verification entries. These 183 declarations include taps and editor extensions,
and duplicate packages between install and verification lists. They are not 183
unique packages. Xcode is also conditionally installed by `install.sh`.

Default mapping: `brew` to native `brew:` packages, `cask` to `brew-cask:`,
existing mise tools remain `[tools]`, `mas` to `mas:`, and editor extensions to
an idempotent editor task. Exclude Stow and the mise formula from the new setup;
install mise through its official bootstrap. Map tap URLs explicitly and verify
SSH Git transport; HTTP artifact/API downloads are not Git transport.

Every entry below needs a row in M0's compatibility ledger with its new owner,
fresh-install result, update result, and recovery.
Do not infer support from a recipe name. Record common/optional/machine scope
and the effective declaration path as well: D9 includes software changes in
private history, and M10b applies them on matching automatic machines. Transfer
installation intent and source manifests, not downloaded binaries or app state.

### New installation scope

The source lists below remain a historical inventory, not the new selection
model. D11 retires grouped profiles and their selection UI.

| New scope | Baseline declarations or new capability |
| --- | --- |
| Common on every Mac | Retained core, except DisplayLink; all cloud, dev, formatters, image, and languages entries below |
| Optional per app/tool; excluded on work | `solidity`, `ethereum`, `stellar-cli`, `foundry`; `obs` with `obs-advanced-scene-switcher`; `camo-studio`; `focusrite-control-2`; `loopback`; `soundsource`; `displaylink`; `asmvik/formulae/skhd` |
| Other optional capability | `busycal`; keep its current optional status |
| New optional app/config owner | `audio-hijack`; installed locally, absent from old manifests |
| Retired everywhere | OpenCode and its exclusive integrations; old profile menus, aliases, presets, and saved selection format |

Each optional capability uses a local native module selection. Do not bundle
them back into work/personal/audio/streaming profiles. Unknown machines receive
the common base; other optional choices are enrollment inputs. An existing
installed app does not authorize deleting its data when its module is disabled.
The work exclusions are explicit; no other machine's full selection was supplied.

The `audio-hijack` recipe exists and is marked self-updating; that establishes a
candidate native `brew-cask:` route, not a completed fresh-install test:
https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/a/audio-hijack.rb

### brewfiles/core

**brew**: `coreutils`, `moreutils`, `findutils`, `gnu-sed`, `gnu-tar`, `grep`,
`jq`, `stow`, `blueutil`, `steipete/tap/remindctl`, `zstd`, `fastfetch`,
`cmake`, `pkg-config`, `cocoapods`, `neovim`, `mise`, `fish`, `fisher`, `tmux`,
`starship`, `bat`, `eza`, `less`, `procs`, `btop`, `tailspin`, `figlet`,
`hyperfine`, `lolcrab`, `tlrc`, `fd`, `ripgrep`, `ast-grep`, `fzf`, `zoxide`,
`rename`, `fswatch`, `watch`, `watchman`, `dust`, `duf`, `rsync`, `git`,
`git-lfs`, `gh`, `worktrunk`, `git-delta`, `actionlint`, `shellcheck`, `wget`,
`curl`, `openssh`, `gnupg`, `gitleaks`, `ykman`, `aria2`, `ffmpeg`, `exiftool`,
`pngquant`, `mozjpeg`, `resvg`, `p7zip`, `mas`, `dockutil`, `duti`, `mole`.

**cask**: `cursor`, `zed`, `ghostty`, `iina`, `1password`, `1password-cli`,
`nordvpn`, `tailscale-app`, `veracrypt`, `macfuse`, `sshfs-mac`, `autofirma`,
`thebrowsercompany-dia`, `google-chrome`, `figma`, `shobhit99/tap/supercmd`,
`obsidian`, `notion`, `cleanshot`, `hammerspoon`, `thaw`, `the-unarchiver`,
`qlmarkdown`, `displaylink`, `linearmouse`, `spotify`, `font-fira-code`,
`font-fira-code-nerd-font`, `font-monaspace`, `font-monaspice-nerd-font`,
`font-hack-nerd-font`, `font-jetbrains-mono`, `font-jetbrains-mono-nerd-font`,
`font-geist`, `font-geist-mono`, `font-geist-mono-nerd-font`, `font-inter`,
`font-lato`, `font-montserrat`, `font-noto-sans`, `font-open-sans`,
`font-poppins`, `font-roboto`, `font-roboto-condensed`, `font-roboto-flex`,
`font-roboto-mono`, `font-source-code-pro`, `discord`, `telegram`, `slack`,
`whatsapp`, `zoom`, `chatgpt`, `claude`, `granola`, `t3-code@nightly`.

**tap**: `shobhit99/tap`.

**vscode**: `catppuccin.catppuccin-vsc`, `vscodevim.vim`.

### brewfiles/profiles/audio

**cask**: `focusrite-control-2`, `loopback`, `soundsource`.

### brewfiles/profiles/cloud

**brew**: `awscli`, `aws-sam-cli`, `kubernetes-cli`, `helm`, `cosign`,
`hashicorp/tap/terraform`.

**cask**: `gcloud-cli`.

### brewfiles/profiles/dev

**brew**: `dive`.

**cask**: `orbstack`, `yaak`, `android-platform-tools`, `apparency`.

### brewfiles/profiles/formatters

**brew**: `shfmt`, `stylua`, `yamlfmt`, `latexindent`, `biome`.

### brewfiles/profiles/image

**brew**: `imagemagick`, `libvips`, `libmagic`, `libavif`, `jpeg`.

### brewfiles/profiles/languages

**brew**: `go`, `lua`, `rustup`, `luarocks`, `perl`, `cpanm`.

### brewfiles/profiles/productivity

**cask**: `busycal`.

### brewfiles/profiles/streaming

**cask**: `camo-studio`, `obs`, `obs-advanced-scene-switcher`.

### brewfiles/profiles/web3

**brew**: `solidity`, `ethereum`, `stellar-cli`, `foundry`.

### brewfiles/profiles/window

**brew**: `asmvik/formulae/skhd`.

### brewfiles/verification

**brew**: `actionlint`, `check-jsonschema`, `editorconfig-checker`, `esbuild`,
`fish`, `git`, `gitleaks`, `lua`, `luacheck`, `neovim`, `python`, `ruby`,
`shellcheck`, `stow`, `stylua`, `taplo`, `wget`.

## Existing global mise tools

Retain these declarations and their actual version/trust settings, except the
explicitly retired OpenCode entry, from
`tools/mise/config/.config/mise/config.toml`; do not copy this inventory into
a second runtime manifest.

- `aqua:anthropics/claude-code`
- `aqua:dlvhdr/gh-dash`
- `aqua:ollama/ollama`
- `aqua:openai/codex`
- `aqua:tree-sitter/tree-sitter`
- `aqua:vercel-labs/agent-browser`
- `bun`
- `deno`
- `dotnet`
- `github:tmuxpack/tpack`
- `github:yt-dlp/yt-dlp`
- `java`
- `markdownlint-cli2`
- `node`
- `npm:2password`
- `npm:@playwright/cli`
- `npm:@code-yeongyu/comment-checker`
- `npm:@luisurrutia/bird`
- `npm:clawpatch`
- `npm:skills`
- `opencode` (retire)
- `pipx:httpie`
- `pipx:pre-commit`
- `pnpm`
- `python`
- `uv`

## Tool Installer disposition

All 39 baseline top-level Tool Installers are covered below, including approved
retirements. Read the exact implementation again at pickup. The source paths
below describe the old layout, not the destination. Move retained behavior to
`conf.d/<capability>`. Preserve dependency eligibility and safe conflicts on
repeat application; old layout converters are outside the new setup contract.

| Tool | Planned owner or preserved behavior |
| --- | --- |
| `ai` | Mise links plus preservation guard for common/local agent instructions; retain override warning. |
| `bat` | Native module entries plus cache-build task. |
| `bin` | Native module entries for public commands; audit brew-dependent wrappers. |
| `btop` | Native module entries; preserve dependency eligibility. |
| `cc-safety-net` | Currently loaded only by OpenCode; retire its exclusive installer/rule deployment after a final consumer check. Preserve untracked local data. |
| `claude` | Native module entries/structured owned-key edits; preserve instruction import and app-owned state. |
| `codex` | Structured TOML merge for managed settings; preserve unrelated configuration. |
| `cspell` | Native module entries; preserve dictionary paths. |
| `curl` | Native module entries and native/keg-only command resolution. |
| `dockutil` | Preserve relative Dock edits unless native complete layout is proved equivalent. |
| `fastfetch` | Native module entries. |
| `fish` | Native module entries, native login shell, one activation owner, fresh Fisher setup. |
| `gh` | Idempotent extension setup task; maintenance owns extension updates. |
| `gh-dash` | Native module entries; existing mise CLI owner. |
| `ghostty` | Native module entries plus config validation. |
| `git` | Native Git module entries, fresh identity templates, safe repeated application, repo hook setup. |
| `hammerspoon` | Native module entries; preserve blueutil dependency and existing automation behavior. |
| `iina` | File-association task. |
| `linearmouse` | Encrypted mutable JSON history plus preference-domain capture; retire the recurring Stow seed owner. |
| `luarocks` | Preserve checks and native/runtime compatibility without brew execution. |
| `macos` | Native user defaults/LaunchAgent plus narrow system tasks. |
| `mise` | Official first-use bootstrap and global configuration enrollment; never install through Homebrew. |
| `node` | Native module entries, npm policy, generated completions; preserve current runtime owner. |
| `opencode` | Retire package/config/installer and cross-tool consumers under D11; no new native module. |
| `orbstack` | Create required Docker plugin links safely; OrbStack remains engine/CLI owner. |
| `python` | Native module entries and completion task; separate maintenance from installation. |
| `ripgrep` | Native module entries. |
| `rustup` | Preserve toolchain, target, and component setup under one declared owner. |
| `skhd` | Native module entries and fresh service registration; Accessibility remains a GUI prerequisite. |
| `skills` | Native module entries plus explicit global-skill installation task; keep SSH origins. |
| `ssh` | Native module entries and directory permissions; preserve OrbStack include ordering and agent rules. |
| `starship` | Native module entries. |
| `thaw` | Replace public plist and timestamped plaintext backups with encrypted capture/restore under M10a. |
| `tlrc` | Native module entries; maintenance retains reference-data updates. |
| `tmux` | Native module entries, isolated validation, TPack setup and SSH transport wrappers. |
| `vim` | Native module entries, Lazy restore, Treesitter/LSP setup; Mason scope remains. |
| `voiceink` | Managed launcher/settings and safe local auth/skill links; never sync credentials/runtime. |
| `wget` | Native module entries. |
| `zed` | Native module entries or format-aware ownership; preserve file associations and JSONC compatibility. |

## Config trees and exclusions

Use all 30 baseline trees to identify retained native configuration targets;
record OpenCode and its exclusive cc-safety-net deployment as intentional
retirements. No Stow link conversion or compatibility test is required. Source
paths are flattened into native modules:

`bat`, `bin`, `btop`, `cc-safety-net`, `claude`, `cspell`, `curl`, `fastfetch`,
`fish`, `gh-dash`, `ghostty`, `git`, `hammerspoon`, `linearmouse`, `macos`,
`mise`, `node`, `opencode`, `python`, `ripgrep`, `skhd`, `skills`, `ssh`,
`starship`, `tlrc`, `tmux`, `vim`, `voiceink`, `wget`, `zed`.

Translate `.stow-local-ignore` in retained Fish, Git, and Claude modules into
explicit mise exclusions; OpenCode's tree is retired. A Git manifest checks
public seed membership but does not replace those rules or provide an index for
regular history-owned sources.
Private history owns effective shared configs and setup sources under D9;
track source contents behind links, not just the links themselves. Preserve
`.gitignore` exceptions for the two VoiceInk source files.
Never deploy `.stow-local-ignore` itself.

Also account for targets created outside Stow: agent instruction links, machine
Git configuration, Codex settings, VoiceInk auth/skill links, generated
completions,
skills, plugin repositories, app associations, and service registration.

### Native destination mapping

These examples establish source layout, not a second package manifest. Apply the
same ownership rule to the rest of the inventory. Existing live target paths stay
explicit in each module's declaration.

| Current source | Proposed source |
| --- | --- |
| `tools/fish/config/.config/fish/config.fish` | `conf.d/fish/config.fish` |
| `tools/fish/config/.config/fish/functions/` | `conf.d/fish/functions/` |
| `tools/git/config/.config/git/local.gitconfig` | `conf.d/git/defaults.gitconfig` |
| `tools/starship/config/.config/starship.toml` | `conf.d/starship/starship.toml` |
| `tools/zed/config/.config/zed/` | `conf.d/zed/` with only its managed source files |
| `tools/vim/config/.config/nvim/` | `conf.d/nvim/` with its real Lua/config subtrees |
| `tools/macos/install.sh` | Native declarations in `conf.d/macos/mise.toml` plus necessary module scripts |
| `tools/mise/config/.config/mise/config.toml` | Root policy in `config.toml`; tool ownership in the corresponding modules |
| `brewfiles/core` | Common declarations in owning modules; config-free tools/apps in `cli`/`apps` |
| `brewfiles/profiles/cloud` | Always-loaded `conf.d/cloud/mise.toml` declarations |
| `brewfiles/profiles/dev`, `formatters`, `image`, `languages` | Common declarations in their owning modules, without environment suffixes |
| Optional app entries, including former core DisplayLink | `conf.d/<app>/mise.<app>.toml` with only that capability's resources |
| `tools/thaw/Thaw.plist` and plaintext backup output | Private encrypted snapshots; public `conf.d/thaw/` contains only declarations/adapters |
| Appearance LaunchAgent plist | Native TOML declaration in `conf.d/macos/mise.toml`; runtime plist is generated |
| `maintenance/`, `config/`, `cli/` behavior | Native operational `tasks/`; optional thin convenience commands |
| `verification/` and component test trees | Reduced `tests/` suite based on retained behavior; see D12 |

Enroll the native root payload into `~/.config/mise` with the same relative paths.
Do not retain a separate active source mirror or deploy module manifests and
scripts into application config directories. Public `machines/` records remain
tracked; local enrollment files remain outside the shared payload.

## Application preference discovery

Read-only local inspection on 2026-10-10 found the following files. Bundle IDs
and versions came from `/Applications/<app>.app/Contents/Info.plist`; preference
paths and Application Support entries were enumerated without reading their
values. This is path evidence, not proof of portable contents or safe restore.
Reconfirm schemas and storage locations against the installed version.

In this table, `Preferences/` means `~/Library/Preferences/`, and `Support/`
means `~/Library/Application Support/`.

| App/version | Existing primary preference path | Additional configuration candidates |
| --- | --- | --- |
| Thaw 2.0.1 | `Preferences/com.stonerl.Thaw.plist` | `Support/Thaw/Profiles/` exists but contained no files at inspection |
| LinearMouse 0.12.0 | `Preferences/com.lujjjh.LinearMouse.plist` | `~/.config/linearmouse/linearmouse.json` is the main config and currently a managed symlink |
| SuperCmd 1.0.9 | `Preferences/com.supercmd.SuperCmd.plist` | Inspect user-authored `Support/SuperCmd/Skills/` and extension settings separately; do not back up runtime directories |
| SoundSource 6.1.4 | `Preferences/com.rogueamoeba.soundsource.plist` | `Support/SoundSource/Models.v2.plist`, `Presets.v2.plist` |
| Loopback 2.5.0 | `Preferences/com.rogueamoeba.Loopback.plist` | `Support/Loopback/Devices.plist` |
| Audio Hijack 4.6.0 | `Preferences/com.rogueamoeba.audiohijack.plist` | `Support/Audio Hijack 4/Sessions.plist`, `Presets.plist`, `Schedule.plist`, `Scripts.plist` |

Also present: `com.stonerl.Thaw.MenuBarItemService.plist`,
`com.rogueamoeba.loopbackd.plist`, and
`com.rogueamoeba.audiohijack.RemoteAUHost.plist` in Preferences. Classify these
helper domains before capture; their existence does not establish user settings.
Schedules and scripts are configuration with execution effects, so restoring
them must not start recording or launch scripts as an incidental backup restore.

All captured plists, XML or binary, require `encrypt = true` from the first save.
Private companion config files receive the same policy. Public modules contain
capture/restore declarations and code, not actual preferences. Use native
tracking when a live regular file supports safe external updates; CFPreferences
domains use explicit snapshots and controlled import as specified in M10a.
Device IDs, screen layout, audio routing, and other machine-bound data need a
verified local application scope even though their encrypted backups travel.

Exclude the observed `Loopback/RecentApps.plist`, `Audio Hijack 4/Recordings.plist`,
and `Loopback/Loopback.app` helper bundle from config backup. Under SuperCmd's
two support directories, exclude `CrashReporting/`, `FileIndex-v2.bin`,
`agent-history.json`, `.Clipboard_SUPPORT/`, `Clipboard.store` and its WAL/SHM
files, `runtime/`, and `sync-state.json`. Inspect extension installation/settings
ownership before enrolling anything from `Extensions/` or
`extension-catalog.json`. Do not capture either whole support directory.
Licenses, tokens, auth state, and recording media stay outside this payload.

The installed SuperCmd is the native app distributed by the current
`shobhit99/tap` cask. Its documented preference domain and support paths match
local inspection. Do not assume the `settings.json` layout found in older or
forked Electron implementations. The canonical release source is
`SuperCmdLabs/SuperCmd-v2-releases`.

Existing plaintext sources are `tools/thaw/Thaw.plist` and the generated output
of `tools/bin/config/.local/bin/thaw-config`. Remove both storage routes from
the rebuilt setup. The other tracked plist is the appearance LaunchAgent;
replace its source with native TOML. No pre-erase backup has been performed.
No public history rewrite is part of this plan, and encryption does not
retroactively protect earlier public commits.

Primary documentation and package metadata:

- https://github.com/linearmouse/linearmouse/blob/main/Documentation/Configuration.md
- https://github.com/thaw-app/Thaw
- https://raw.githubusercontent.com/shobhit99/homebrew-tap/main/Casks/supercmd.rb
- https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/a/audio-hijack.rb
- https://rogueamoeba.com/support/manuals/audiohijack/
- https://mise.jdx.dev/dotfiles/encryption.html

The local `defaults(1)` manual explicitly warns that a running app may ignore or
overwrite external changes. No live preference export, restore, encryption, or
application restart was performed during this planning inspection.

## OpenCode retirement surface

`rg` found these consumers beyond `tools/opencode/`; remove them with the owning
module so the new setup has no dangling command or plugin references:

| Owner | Removal or retained boundary |
| --- | --- |
| Global mise config | Remove the `opencode` declaration; omit it from the fresh setup |
| Fish `03_abbrs.fish`, `help-aliases.fish`, `tds.fish` | Remove `c`/`oc` shortcuts and OpenCode pane/autolaunch; preserve the remaining tmux layout |
| Starship config | Remove `custom.opencode` and its prompt reference |
| Zed settings | Remove OpenCode agent-server integration and defaults |
| Neovim `lua/plugins/ai.lua`, `lazy-lock.json` | Remove OpenCode plugin, bindings, and lock entry; keep unrelated dependencies |
| gh-dash config | Remove OpenCode launch from the PR action; preserve useful Worktrunk navigation |
| Skills installer | Remove OpenCode from target agents; retain other agents |
| `cc-safety-net` | Repository installer documents OpenCode as its plugin consumer; retire exclusive deployment after confirming no other consumer |
| Verification | Remove OpenCode schema/autoupdate checks, completion fixtures, and exact skills-command expectations |
| Documentation and ignore rules | Remove active OpenCode instructions and obsolete generated-file rules |

Preserve untracked OpenCode conversations, credentials, and other local data.
Do not substitute Claude/Codex for its commands without a separate user choice.
Use a final repository search and affected editor/shell smoke check to verify
retirement; do not add a permanent test that merely searches for the word.

## Test disposition evidence

These inspected examples inform D12; they are not a request to delete all tests
in these files without separating retained behavior:

| Current test/check | Decision and useful replacement |
| --- | --- |
| `verification/tests/install-selection.sh` | Retire profile prompts, alias/selection matrix, and many internal function fakes. Keep failed-install status and resumability at the new entrypoint. |
| `tools/bin/tests/thaw-config.sh` | It copies a text fixture named `.plist` and counts timestamped backups. Replace with a valid typed plist encrypted save/restore scenario. |
| `maintenance/tests/backup.sh` | Consolidate wrapper/output-string checks into the preference capture scenario; keep meaningful failure reporting. |
| `tools/skills/tests/install.sh` | Drop exact full-command snapshots and the OpenCode target. Check intended installed agent targets only where repo behavior needs protection. |
| `verification/check-configs.py` and schemas | Retain relevant parser/schema checks, remove OpenCode policy, and avoid maintaining redundant format parsers or string checks. |
| Git identity/migration and config preservation tests | Keep correct identity, unrelated-key preservation, and refusal to overwrite foreign state; remove old Git-layout migration tests. |

Use four cohesive integration areas: safe/repeatable configuration; Git identity;
encrypted app recovery; and manual/automatic setup exchange. A case belongs only
if it protects a distinct retained contract. Package, TCC, and real app restore
acceptance stays a focused macOS checklist outside normal CI. Native mise feature
experiments are version-selection evidence, not a second upstream test suite.

## Highest-risk package cases

- Self-updating/TCC-sensitive apps: Slack, Discord, Zoom, ChatGPT, T3 Code,
  Hammerspoon, CleanShot, and other apps requiring privacy permissions. Verify
  first-use grants and subsequent updates on the new setup.
- Driver/pkg/security installs: DisplayLink, macFUSE, sshfs-mac, Tailscale,
  NordVPN, VeraCrypt, AutoFirma, and audio tools.
- Third-party taps: remindctl, SuperCMD, Terraform, and skhd.
- OBS scene-switcher and other artifacts installed inside another app.
- Keg-only tools/native libraries, compiler flags, dynamic linking, and commands
  depending on the current `/opt/homebrew/opt` layout.
- Fish/Fisher/completions and services that start without interactive shell
PATH.
- Xcode/App Store authentication and post-install setup.
- `vscode` entries: an editor extension task must select the intended installed
  editor and preserve the existing behavior rather than silently drop them.

These are investigation priorities, not findings that those packages fail.

## Cross-cutting consumers to rebuild

Inspect and rebuild these current consumers with their owning units. Their names
are source pointers, not instructions to retain the existing structure:

- `install.sh`, `bootstrap/`, `private-install.sh`, `dotfiles`, and `cli/`.
- `tools/lib.sh`, `tools/catalog.sh`, and each listed Tool Installer.
- `config/run.sh` and its lifecycle/resolution tests; history-owned source
  resolution, public import/promotion, and serial full-setup application.
- `maintenance/update.sh`, `maintenance/backup.sh`, and their Fish
abbreviations.
- Fish PATH/completion setup, `tools/bin` wrappers, and tool-specific opt paths.
- `verification/run.sh`, `verification/groups/`, `brewfiles/verification`, and
CI.
- `.githooks/`, `.config/wt.toml`, README, POST_INSTALL, CONTEXT, and AGENTS.

The instructions mention a package-ownership ADR, but no separate tracked ADR
was found at this baseline. Use README's Package ownership section and the
executable declarations as current evidence; reconcile that documentation during
M14 instead of assuming an inaccessible ADR's contents.

## Research and probe evidence

All user-linked mise pages were inspected on 2026-10-10. Additional sources for
fresh install and shell setup:

- https://mise.jdx.dev/bootstrap.html
- https://mise.jdx.dev/bootstrap/setup.html
- https://mise.jdx.dev/installing-mise.html
- https://mise.jdx.dev/shell-setup.html
- https://mise.jdx.dev/bootstrap/packages/mas.html

Other capability URLs appear beside their decisions. The official GitHub release
API reported v2026.10.7 published 2026-10-09T23:43:50Z; this was too recent for
the default three-day cooldown at inspection. The installed build was
2026.10.1. Choose the implementation baseline after both age and feature checks,
rather than assuming current web examples work on that installed version.

Release evidence: https://api.github.com/repos/jdx/mise/releases

A temporary Python probe invoked installed mise with an isolated HOME, XDG,
config, data, cache, and state; offline mode; stdin disabled; and only synthetic
files. Observed results:

- `mise dot apply --yes`: repointed a foreign symlink, exit 0; foreign source
  content remained intact.
- `mise dot apply --yes`: replaced an edited regular copy target, exit 0.
- `mise config`: loaded symlinked global config, the selected work environment,
  and a `conf.d` fragment, exit 0.
- `mise env --json`: returned all three synthetic markers, exit 0.
- `mise vars --json`: unavailable on installed 2026.10.1, exit 1.

The disposable probe lived under `/tmp/dotfiles-mise-research/`; it is not a
durable test artifact. M0 must use these observations to verify the selected mise
version and the repo's preservation guard. Maintain only the cases that protect
that boundary, not a suite retesting upstream behavior. Only these conclusions,
their conditions, and their limits are retained here.

A later module-layout probe used regular global files and no public-checkout
symlinks. It ran `python3 /tmp/dotfiles-mise-research/module-layout-probe.py` with
isolated HOME/XDG/config/data/state/cache, offline mode, disabled history, synthetic
sources, and stdin closed. On mise 2026.10.1, all operations exited 0:

- `mise config`: discovered `conf.d/fish/mise.toml` beside the global base.
- `mise env --json`: loaded base/Fish markers, then the dev marker only after
  `miserc.local.toml` selected `dev` and `conf.d/editor/mise.dev.toml` became active.
- `mise dot apply --yes`: linked direct config files and each file in two
  application subdirectories from module-relative sources; destinations stayed
  real directories and did not receive the module manifest.
- `mise run layout-probe`: discovered and ran a global task from `tasks/`.

This proves the native folder structure on that build, not private-history
enrollment, package installation, synchronization, or every module's task paths.
The probe is a disposable design check; M0 must verify composition against the
chosen release. Keep a small effective-config smoke check rather than a test for
every module or profile combination. No live configuration or software changed.

The user subsequently confirmed full setup synchronization, including software
installation. D9/D10 and M10/M10b now include package declarations, setup sources,
and automatic application; the earlier composition probes do not establish that
protocol. The subsequent user correction replaced the Stow-shaped source layout
with native colocated modules. These revisions add planning contracts and the
bounded structural probe above; full behavioral acceptance remains M0/M10b work.
An earlier scope correction retires installation profiles and OpenCode, makes
five former categories common, and adds encrypted preference recovery. Local
app/path discovery above adds no evidence of actual capture or restore.
The latest decision, D13, limits implementation to fresh macOS installations.
M13 and existing Homebrew/Stow transfer checks are cancelled; fresh installation,
update, repeated application, and recovery checks remain.

## Planning-artifact validation

The following commands passed on 2026-10-10. The temporary markdownlint config
contained `{"config":{"MD013":{"tables":false},"MD034":false}}`: tables may
exceed 80 columns and project instructions require bare source URLs. Other default
Markdown rules remained enabled. The initial default-only lint reported those
style conflicts and long inventory paragraphs; paragraphs were wrapped before
the final pass.

```sh
markdownlint-cli2 \
  --config /tmp/dotfiles-mise-research/markdownlint-cli2.jsonc \
  plans/mise-migration.md plans/mise-migration-decisions.md \
  plans/mise-migration-inventory.md
editorconfig-checker README.md plans/mise-migration.md \
  plans/mise-migration-decisions.md plans/mise-migration-inventory.md
gitleaks detect --source plans --no-git --redact --no-banner
./dotfiles --help
git diff --check
```

A one-off Python check also verified local Markdown links, every inventoried
package declaration, all 39 installer names, all 30 config trees, and that Git
does not ignore the plan files. No application build or full behavioral suite
was run for this documentation-only change. The future setup checks in the
plan remain unexecuted.
