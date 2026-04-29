set -gx EDITOR nvim
set -gx VISUAL nvim

status is-interactive; or return

set -g fish_key_bindings fish_vi_key_bindings
