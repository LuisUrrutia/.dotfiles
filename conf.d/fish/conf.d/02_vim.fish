set -q EDITOR; or set -gx EDITOR nvim
set -q VISUAL; or set -gx VISUAL nvim

status is-interactive; or return

set -g fish_key_bindings fish_vi_key_bindings
