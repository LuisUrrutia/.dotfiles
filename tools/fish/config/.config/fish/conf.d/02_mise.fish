# Sorted after 01_paths so Homebrew's mise is on PATH, and before the conf.d
# files that probe for mise-managed tools such as uvx. Vendor auto-activation
# stays off so mise activates exactly once.
set -gx MISE_FISH_AUTO_ACTIVATE 0

# mise is brew-managed; Dotfiles Update handles upgrades, so skip the new-version nag.
set -gx MISE_HIDE_UPDATE_WARNING 1

command -q mise; or return

if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims 2>/dev/null | source
end
