# SuperCmd Homebrew installation

Verified on 2026-09-13 against the product website, current cask source, release
metadata, and the installed app.

SuperCmd is installed automatically by `./dotfiles install`. The Bootstrapper
passes `brewfiles/core` to `brew bundle install`, which registers the tap and
installs the cask alongside the other core apps. The Brewfile declares:

```ruby
tap "shobhit99/tap", "git@github.com:shobhit99/homebrew-tap.git", trusted: true
cask "shobhit99/tap/supercmd", trusted: true
```

The tap uses SSH to follow the repository's Git transport rule. The cask is
the one specified by the SuperCmd v2 website: https://supercmd.sh/en

The cask currently installs version **1.0.7** from the v2 release repository.
Its SHA-256 is
`b39f922745348de1e8236fd1e750300ddeff2e68f4b306d01c42026283cceceb`, which
matches the release asset's published digest. Version 1.0.7 is the latest
non-prerelease release, published on 2026-09-03.
https://api.github.com/repos/shobhit99/homebrew-tap/contents/Casks/supercmd.rb
https://api.github.com/repos/SuperCmdLabs/SuperCmd-v2-releases/releases/latest
https://github.com/SuperCmdLabs/SuperCmd-v2-releases/releases/tag/1.0.7

The installed `/Applications/SuperCmd.app/Contents/Info.plist` reports version
**1.0.7**, build **8**, bundle identifier `com.supercmd.SuperCmd`, and the v2
Sparkle feed. The feed also reports version 1.0.7 and build 8. Thus "v2" is
the product generation; its current bundle version remains 1.0.7.
https://github.com/SuperCmdLabs/SuperCmd-v2-releases/blob/main/appcast.xml

Do not select `supercmdlabs/supercmd/supercmd`: that separate tap still installs
the old open-source app, version 1.0.26, from `SuperCmdLabs/SuperCmd`. Both
casks install `SuperCmd.app`, so use the fully qualified v2 cask name.
https://github.com/SuperCmdLabs/homebrew-supercmd/blob/main/Casks/supercmd.rb

Upstream requirements differ: the website says macOS 26 or later, while the
cask declares `macos: :sequoia` and the update feed specifies 15.0. The website
describes a lifetime license with a one-time payment.
https://supercmd.sh/en
https://api.github.com/repos/shobhit99/homebrew-tap/contents/Casks/supercmd.rb
https://github.com/SuperCmdLabs/SuperCmd-v2-releases/blob/main/appcast.xml

## Repository verification

All commands below completed with exit status 0. Homebrew Bundle's cask list
includes `supercmd` and excludes `raycast`, `codexbar`, and `cadran`.
No live app was installed or uninstalled during verification.

```bash
/bin/bash brewfiles/check.sh
/bin/bash brewfiles/tests/cleanup.sh
HOMEBREW_NO_AUTO_UPDATE=1 /opt/homebrew/bin/brew bundle list --file brewfiles/core --cask
/bin/bash -n tools/macos/install.sh
/opt/homebrew/bin/shellcheck tools/macos/install.sh
/bin/bash tools/macos/tests/install.sh
/bin/bash tools/bin/tests/dotfiles.sh
/bin/bash tools/raycast/tests/backup.sh
/bin/bash maintenance/tests/backup.sh
/bin/bash install.sh --dry-run
/bin/bash install.sh --dry-run --core-only
/bin/bash install.sh --dry-run --all-profiles
/bin/bash install.sh --dry-run --profile web3,streaming,audio
/bin/bash install.sh --dry-run --profile blockchain,obs,focusrite
DOTFILES_HARDWARE_HASH_OVERRIDE=55930b1d4d8e /bin/bash install.sh --dry-run
/opt/homebrew/bin/editorconfig-checker brewfiles/core README.md POST_INSTALL.md tools/macos/install.sh tools/raycast/README.md tools/supercmd/RESEARCH.md
git diff --check
```
