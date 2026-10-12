# Domain language

- **Public seed**: this Git repository's reviewed initial configuration and setup
  sources. It is not the active owner after enrollment.
- **Active setup**: regular files in `~/.config/mise`, managed by private native
  mise history. Application symlinks point here.
- **Module**: one capability in `conf.d/<name>`, containing native declarations
  and its real configuration sources. A `mise.macos.toml` fragment adds Mac-only
  resources. A `mise.<app>.toml` fragment selects one optional capability.
  Related optional apps can share a module directory, as the audio apps do.
- **Local enrollment**: `config.local.toml` and `miserc.local.toml`, excluded from
  shared history. They own this machine's identity, origin, sync mode, and apps.
- **Machine record**: public defaults in `machines/<stable-id>.toml`. Hardware
  lookup supplies the Mac ID; Linux hashes `/etc/machine-id`. `--machine` can retain
  a Linux enrollment ID across reinstalls.
- **Setup history**: mise's private Git-backed checkpoints of declarations,
  active sources, plugin manifests, and encrypted preference snapshots.
- **Public recovery backup**: allowlisted preferences captured manually or daily
  on enrolled Macs under
  `backups/preferences/*.plist.age`, plus `backups/recovery.age`, a password-sealed
  age identity. Only ciphertext and its public recipient enter the checkout.
  The age CLI owns this export format; native mise still owns operational history.
  Recovery unlocks a local identity and stages snapshots for the existing importer.
- **Application state**: local pending/applied fingerprints, retries, maintenance
  stamps, and drift backups under mise's state directory. It never travels.
- **Preference snapshot**: an allowlisted app export encrypted before history
  storage. Live files remain readable. Hardware-bound snapshots are keyed by
  stable machine ID; shared ones have explicit portability scope.
  `preferences.json` uses the module's name; `preferences.<app>.json` retains
  an individual app's identity within a grouped module.
- **Manual exchange**: the native watcher saves locally, while the user runs
  `sync` to exchange and apply setup.
- **Automatic exchange**: a local scheduler runs that same serial command.
  Native history still uses manual network mode to keep one incoming owner.
- **Safe bootstrap**: preserve unknown files and foreign symlinks, require an
  explicit capture/discard decision for drift, and return failure for required
  resources that could not be installed or applied. A repeated seed never resets
  active changes. Optional selection does not authorize deletion.

Installation targets: fresh macOS arm64 and Ubuntu arm64/x86_64. Existing-machine
migration, Homebrew/Stow conversion, Arch package mapping, and destructive package
pruning are outside this implementation. Native brew recipes are mise-owned
packages and do not imply the Homebrew executable is present.
