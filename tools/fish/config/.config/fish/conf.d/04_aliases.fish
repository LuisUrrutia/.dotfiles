status is-interactive; or return

alias ls 'eza --icons --color=auto --group-directories-first --octal-permissions'
alias ll 'ls --git -alhF'
alias tree 'ls --tree'
alias vim nvim
alias f 'open -a Finder ./'

alias tldr 'tldr --config ~/.config/tlrc/config.toml'

alias frida "uvx --from frida-tools frida"
alias frida-ls "uvx --from frida-tools frida-ls"
alias frida-trace "uvx --from frida-tools frida-trace"
alias frida-ps "uvx --from frida-tools frida-ps"
alias frida-discover "uvx --from frida-tools frida-discover"
alias frida-kill "uvx --from frida-tools frida-kill"
alias frida-pull "uvx --from frida-tools frida-pull"
alias frida-push "uvx --from frida-tools frida-push"
alias frida-ls-devices "uvx --from frida-tools frida-ls-devices"

alias llama "uvx --from llama-stack llama"

alias clean-rust "cd $TMPDIR/../C/ && rm -rf com.Facepunch-Studios-LTD.Rust/"

alias cursor 'open $argv -a "Cursor"'
alias ip 'dig +short myip.opendns.com @resolver1.opendns.com || \curl https://checkip.amazonaws.com'
alias ports 'lsof -i -P | grep LISTEN'
alias netcons 'lsof -i'
alias flushdns 'dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
alias tailscale '/Applications/Tailscale.app/Contents/MacOS/Tailscale'

alias sha256sum gsha256sum
alias sed gsed
alias tar gtar
alias grep ggrep
