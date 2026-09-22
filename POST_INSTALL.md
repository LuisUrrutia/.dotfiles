# Post-install checklist

Single source for manual steps after `./install.sh`. The installer prints this
file at the end of a run.

- Restart the terminal to apply shell changes.
- Configure SuperCMD's preferences.
- Set up 1Password:
  - Save the Recovery Key.
  - Settings > Touch ID > Enable Apple Watch.
  - 1Password > Settings > Apple Watch.
- Complete CleanShot setup.
- Add Bluetooth permission for Hammerspoon in System Settings > Privacy &
  Security > Bluetooth.
- Allow Ghostty under System Settings > Privacy & Security > Developer Tools.
- For Safari device debugging, enable Web Inspector on the iPhone or iPad under
  Settings > Apps > Safari > Advanced. Connect it to the Mac and trust the Mac
  when prompted, then open a page and select it under Safari > Develop > device.
- Run `remindctl authorize` to grant Reminders access.
- Profile-specific steps:
  - `dev`: finish Docker Desktop setup.
  - `audio`: configure SoundSource and Loopback licenses.
  - `productivity`: configure BusyCal.
  - `streaming`: configure OBS.
