# Post-install checklist

Single source for manual steps after `./install.sh`. The installer prints this
file at the end of a run.

- Restart the terminal to apply shell changes.
- Restore Raycast with `raycast-config restore`, then configure HyperKey in
  Raycast Settings > Advanced.
- Set up 1Password:
  - Save the Recovery Key.
  - Run `install-ssh-key-from-1password` if you want a local SSH key.
  - Settings > Touch ID > Enable Apple Watch.
  - 1Password > Settings > Apple Watch.
- Complete CleanShot setup.
- Add Bluetooth permission for Hammerspoon in System Settings > Privacy &
  Security > Bluetooth.
- Allow Ghostty under System Settings > Privacy & Security > Developer Tools.
- Run `remindctl authorize` to grant Reminders access.
- Set Fliqlo manually as the active screensaver.
- Install or configure Insta360 Link Controller if needed.
- Profile-specific steps:
  - `dev`: finish Docker Desktop setup.
  - `audio`: configure SoundSource and Loopback licenses.
  - `productivity`: configure BusyCal.
  - `streaming`: configure OBS.
