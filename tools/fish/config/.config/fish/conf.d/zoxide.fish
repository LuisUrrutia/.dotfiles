status is-interactive; or return

if command -q zoxide
    zoxide init fish | source
    alias cd=z
end
