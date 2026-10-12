# Vendor activation must stay disabled: this is the single activation owner.
set -gx MISE_FISH_AUTO_ACTIVATE 0
command -q mise; or return
if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims | source
end
