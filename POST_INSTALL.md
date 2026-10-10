# Fresh-Mac acceptance

Repository checks use isolated files and synthetic data. They cannot establish
that a driver installed, a GUI app launched, or macOS granted permissions. Run
this checklist on a fresh Apple Silicon Mac; do not use the old Homebrew-owned
installation as a substitute.

1. Complete Full Disk Access, Command Line Tools, and sudo prerequisites, in that
   order. Enroll private SSH access, age identity plus recovery recipient, Git
   identity, optional apps, and manual/automatic mode. Keep private inputs out of
   the public repository.
2. Install the common setup and selected apps. Confirm `command -v brew` and
   `command -v stow` find nothing. Inspect `mise bootstrap packages status`,
   `mise dot status`, services, defaults, and login-shell status. A required skip
   or unsupported recipe is a failure, not a completed installation.
   Complete AutoFirma's prepared vendor installer when its task requests it,
   then rerun setup and verify its receipt and application. Its installation
   requires GUI interaction; do not suppress the vendor's dialogs.
3. Launch Fish, Ghostty, Neovim, tmux, editors, OrbStack, and common GUI apps.
   Check Fisher completions/bindings, plugin restoration, Docker plugins, file
   associations, and Git identity/signing in normal repositories and worktrees.
4. Sign into the App Store before the optional Xcode step. Accept licenses,
   enable FileVault, record its recovery key outside history, and set immediate
   screen lock. Grant Accessibility/Screen Recording/Full Disk Access to the
   applications that need them. Authorize driver/system extensions explicitly.
5. Repeat `mise -C ~ run config apply`. Preserve edits and unknown files. Change
   an app-owned setting and check drift handling. Interrupt a disposable setup
   and confirm a rerun resumes without a false applied stamp.
6. Update formulae, casks, self-updating apps, plugins, and runtimes with
   `mise -C ~ run update --ignore-schedule`. Check app launches and privacy
   grants again. Bundle replacement can reset TCC grants. Check macFUSE/sshfs,
   VPN/security apps, third-party taps, OBS plugin, and audio tools individually.
7. Change one setting in each enabled captured app: Thaw, LinearMouse, SuperCmd,
   SoundSource, Loopback, Audio Hijack. Capture, inspect ciphertext in history,
   close the app and its writers, restore, and reopen. Check actual device,
   session, preset, and layout behavior. Confirm no recording or script starts
   incidentally. Check recovery with the separate key and failure without a key.
8. Use a second disposable machine with the same private history. Check shared
   Fish/Starship edits, a real common package addition, a selected optional app,
   and a new setup task/source. Verify manual mode waits and automatic mode
   applies, while disabled apps and machine-bound settings remain untouched.
9. Test simultaneous edits, missing network/SSH/sudo, pending active-app restore,
   repeated wakeups, failed installation/retry, and native interrupted-pull
   recovery. Verify no configuration-only loop reinstalls packages indefinitely.

Record the Mac/mise/app versions, exact commands, results, and unresolved entries
in `plans/mise-compatibility.md`. Back up wanted settings from the old Mac before
formatting through a separately authorized backup; this rewrite has not captured
the operator's live preferences or created the private remote.
