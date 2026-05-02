# Raycast

Raycast settings are managed through exported `.rayconfig` backups.

Raycast does not expose a stable external CLI for fully automated export/import,
so `raycast-config` uses Raycast's built-in export/import flows and keeps the
file handling explicit.

## Commands

```sh
raycast-config status
raycast-config list
raycast-config backup
raycast-config backup --timeout 600
raycast-config backup --manual
raycast-config backup --no-open
raycast-config backup ~/Downloads/Raycast\ 2026-05-02\ 12.00.00.rayconfig
raycast-config restore
raycast-config restore "Raycast 2026-05-02 12.00.00.rayconfig"
raycast-config path latest
```

`backup` without an argument opens Raycast's `Export Settings & Data` command,
uses AppleScript to press Return through the confirmation/export/save dialogs,
then waits for a new `Raycast*.rayconfig` export in `~/Downloads` and copies it
into `tools/raycast/backups`.

The automated path requires macOS Accessibility permission for the terminal app
running `raycast-config`. If the UI changes or automation fails, run
`raycast-config backup --manual` to open the export flow and finish the dialogs
yourself.

`backup --no-open` skips opening Raycast and only waits for a new export. Use
this if Raycast is already open or if you triggered the export manually.

`restore` defaults to the newest stored backup, so there is no separate `latest`
command. `path latest` exists for scripting when you only need the selected file
path.

## Security

Treat `.rayconfig` exports as sensitive. Keep private exports in the private
dotfiles layer if they include private URLs, extension settings, snippets, or
API-adjacent configuration. Never commit the export passphrase.
