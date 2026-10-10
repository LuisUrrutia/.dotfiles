# Mise migration: scope inventory

Baseline: `0c2f8fe3739a1e16e80d07d476453bf119db55dc`, inspected 2026-10-10.

This is a declaration inventory, not proof that every package is installed or
supported by mise. Extend it with each target Mac's read-only installed
inventory
during M0. Preserve undeclared installed software until its owner is resolved.

See the [plan](mise-migration.md) and [decision
map](mise-migration-decisions.md).

## Package declarations

The current source has 126 core entries, 40 optional-profile entries, and 17
verification entries. These 183 declarations include taps and editor extensions,
and duplicate packages between install and verification lists. They are not 183
unique packages. Xcode is also conditionally installed by `install.sh`.

Default mapping: `brew` to native `brew:` packages, `cask` to `brew-cask:`,
existing mise tools remain `[tools]`, `mas` to `mas:`, and editor extensions to
an idempotent editor task. Remove the mise and Stow formula declarations only
after their replacement gates pass. Map tap URLs explicitly and verify SSH Git
transport; HTTP artifact/API downloads are not Git transport.

Every entry below needs a row in M0's compatibility ledger with its new owner,
fresh-install result, existing-install transfer, update result, and recovery.
Do not infer support from a recipe name. Record shared/profile/machine scope
and the effective declaration path as well: D9 includes software changes in
private history, and M10b applies them on matching automatic machines. Transfer
installation intent and source manifests, not downloaded binaries or app state.

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

Retain these declarations and their actual version/trust settings from
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
- `opencode`
- `pipx:httpie`
- `pipx:pre-commit`
- `pnpm`
- `python`
- `uv`

## Tool Installer disposition

All 39 top-level Tool Installers are covered below. The exact implementation
must be read again at pickup. The source paths below describe the old layout,
not the destination. Move cohesive behavior to `conf.d/<capability>`; remove a
stow-only installer after native entries preserve eligibility and safe conflicts.

| Tool | Planned owner or preserved behavior |
| --- | --- |
| `ai` | Mise links plus preservation guard for common/local agent instructions; retain override warning. |
| `bat` | Native module entries plus cache-build task. |
| `bin` | Native module entries for public commands; audit brew-dependent wrappers. |
| `btop` | Native module entries; preserve dependency eligibility. |
| `cc-safety-net` | Native module entries, excluding mutable rule locks and runtime state. |
| `claude` | Native module entries/structured owned-key edits; preserve instruction import and app-owned state. |
| `codex` | Structured TOML merge for managed settings; preserve unrelated configuration. |
| `cspell` | Native module entries; preserve dictionary paths. |
| `curl` | Native module entries and native/keg-only command resolution. |
| `dockutil` | Preserve relative Dock edits unless native complete layout is proved equivalent. |
| `fastfetch` | Native module entries. |
| `fish` | Native module entries, native login shell, one activation owner, Fisher setup and migration. |
| `gh` | Idempotent extension setup task; maintenance owns extension updates. |
| `gh-dash` | Native module entries; existing mise CLI owner. |
| `ghostty` | Native module entries plus config validation. |
| `git` | Native Git module entries, identity templates, guarded migration, repo hook setup. |
| `hammerspoon` | Native module entries; preserve blueutil dependency and existing automation behavior. |
| `iina` | File-association task. |
| `linearmouse` | Choose explicit source or mutable-history ownership; preserve app eligibility. |
| `luarocks` | Preserve checks and native/runtime compatibility without brew execution. |
| `macos` | Native user defaults/LaunchAgent plus narrow system tasks. |
| `mise` | Official first-use bootstrap and global configuration enrollment; retire brew owner. |
| `node` | Native module entries, npm policy, generated completions; preserve current runtime owner. |
| `opencode` | Native module entries with runtime exclusions; mutable settings need explicit live-file ownership. |
| `orbstack` | Retain safe Docker plugin-link migration; OrbStack remains engine/CLI owner. |
| `python` | Native module entries and completion task; separate maintenance from installation. |
| `ripgrep` | Native module entries. |
| `rustup` | Preserve toolchain, target, and component setup under one declared owner. |
| `skhd` | Native module entries and verified service handoff; Accessibility remains a GUI prerequisite. |
| `skills` | Native module entries plus explicit global-skill installation task; keep SSH origins. |
| `ssh` | Native module entries and directory permissions; preserve OrbStack include ordering and agent rules. |
| `starship` | Native module entries. |
| `thaw` | Preserve preference import/export, app restart behavior, and backup command. |
| `tlrc` | Native module entries; maintenance retains reference-data updates. |
| `tmux` | Native module entries, isolated validation, TPack setup and SSH transport wrappers. |
| `vim` | Native module entries, Lazy restore, Treesitter/LSP setup, legacy migration; Mason scope remains. |
| `voiceink` | Managed launcher/settings and safe local auth/skill links; never sync credentials/runtime. |
| `wget` | Native module entries. |
| `zed` | Native module entries or format-aware ownership; preserve file associations and JSONC compatibility. |

## Config trees and exclusions

All 30 existing trees must be included in the Stow-to-mise target parity check.
Their source paths are flattened into native modules, not preserved:

`bat`, `bin`, `btop`, `cc-safety-net`, `claude`, `cspell`, `curl`, `fastfetch`,
`fish`, `gh-dash`, `ghostty`, `git`, `hammerspoon`, `linearmouse`, `macos`,
`mise`, `node`, `opencode`, `python`, `ripgrep`, `skhd`, `skills`, `ssh`,
`starship`, `tlrc`, `tmux`, `vim`, `voiceink`, `wget`, `zed`.

Translate `.stow-local-ignore` in Fish, Git, Claude, and OpenCode into explicit
mise exclusions. A Git manifest checks public seed membership but does not
replace those rules or provide an index for regular history-owned sources.
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
| `brewfiles/profiles/cloud` | Optional `conf.d/cloud/mise.cloud.toml` declarations |
| `maintenance/`, `config/`, `cli/` behavior | Native operational `tasks/` and thin compatibility routing |
| `verification/` and component test trees | `tests/` with preserved behavioral coverage |

Enroll the native root payload into `~/.config/mise` with the same relative paths.
Do not retain a separate active source mirror or deploy module manifests and
scripts into application config directories. Public `machines/` records remain
tracked; local enrollment files remain outside the shared payload.

## Highest-risk package cases

- Existing Homebrew-owned casks: status recognition is not ownership transfer.
- Self-updating/TCC-sensitive apps: Slack, Discord, Zoom, ChatGPT, T3 Code,
  Hammerspoon, CleanShot, and other apps with granted privacy permissions.
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

## Cross-cutting consumers to migrate

Inspect and migrate these current consumers with their owning units. Their names
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
durable test artifact. M0 must turn the relevant observations into maintained
fixtures against the selected mise version. Only these conclusions, their
conditions, and their limits are retained here.

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

This proves the native folder structure on that build, not full adoption, package
installation, synchronization, or task-path behavior in every module. The probe
is a disposable design check; M0 must preserve its relevant cases as maintained
fixtures. No live configuration or installed software changed.

The user subsequently confirmed full setup synchronization, including software
installation. D9/D10 and M10/M10b now include package declarations, setup sources,
and automatic application; the earlier composition probes do not establish that
protocol. The subsequent user correction replaced the Stow-shaped source layout
with native colocated modules. These revisions add planning contracts and the
bounded structural probe above; full behavioral acceptance remains M0/M10b work.

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
was run for this documentation-only change. The future migration checks in the
plan remain unexecuted.
