# Repo config.fish activates mise explicitly; keep vendor auto-activation off.
set -gx MISE_FISH_AUTO_ACTIVATE 0

# mise is brew-managed; upd handles upgrades, so skip the new-version nag.
set -gx MISE_HIDE_UPDATE_WARNING 1
