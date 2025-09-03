status is-interactive || exit

set -gx ATUIN_NOBIND "true"
atuin init fish --disable-up-arrow | source

bind \cr _atuin_search
bind -M insert \cr _atuin_search