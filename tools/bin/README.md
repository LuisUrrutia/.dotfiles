# bin

Standalone scripts stowed into `~/.local/bin` (see `install.sh`, which runs
`stow_config bin`).

## Scripts

- `gha-pins` — audit GitHub Actions `uses:` entries for full-SHA pins
  (`audit`, used by CI), rewrite them in place to the latest release
  (`update`), or print a pinned line for one action (`latest`).
- `git-wtf` — read-only summary of the current branch: upstream divergence,
  in-progress operation (rebase/merge/…), and working-tree counts.
- `machash` — print this Mac's hardware hash, used to match
  `machines/<hash>.sh` records.
- `macfuse-guard` — pin macFUSE while Homebrew offers the broken 5.3.3
  release, then unpin it when another version becomes available.
- `openclaw-mount` — mount `voidcore:.openclaw` through SSHFS only while
  Tailscale is connected, and manage its login LaunchAgent.
- `thaw-config` — back up Thaw preferences into `tools/thaw/backups`.

## Tests

`tests/` holds self-contained test scripts (fake `op`/`jq`/`gh` binaries,
temp HOMEs — no network or real credentials). CI runs every
`tools/*/tests/*.sh`; run one locally with `bash tests/<name>.sh`.
