# Hammerspoon — macOS platform constraints

Verified 2026-07 on macOS 26. These two facts shape this config; re-verify them before building anything they rule out.

## `askForPassword` defaults are dead

macOS ignores `defaults write com.apple.screensaver askForPassword` and `askForPasswordDelay`. The effective lock lives behind `sysadminctl -screenLock`, which demands an admin password interactively — no script or daemon can toggle it silently. Verified here: defaults read back `askForPassword=1, delay=0` while `sysadminctl -screenLock status` reported a 300-second delay.

A `utils/screensaver.lua` that flipped these keys on home WiFi was deleted for this reason — it never worked. If lock behavior ever needs automating, `sysadminctl -screenLock` (interactive) is the only path.

## BSSID is redacted; SSID requires Location Services

Since macOS 14.4, CoreWLAN returns a nil BSSID to third-party apps even with Location Services authorized, so networks cannot be pinned to a specific access point. The SSID is available only while Hammerspoon holds Location Services permission — `hs.location.get()` triggers the prompt; without it `hs.wifi.currentNetwork()` returns nil.

`caffeinate_at_home` therefore trusts the SSID alone, and is limited to managing caffeinate: the worst an SSID spoofer can do is keep the Mac awake. Keep anything security-sensitive off SSID-based triggers.
