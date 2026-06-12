status is-interactive; or return

if command -q eza
    alias ls 'eza --icons --color=auto --group-directories-first --octal-permissions'
    alias ll 'ls --git -alhF'
    alias tree 'ls --tree'
end

if command -q nvim
    alias vim nvim
end
alias f 'open -a Finder ./'

if command -q tldr
    alias tldr 'tldr --config ~/.config/tlrc/config.toml'
end

if command -q uvx
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
end

function clean-rust -d "Remove Rust game cache"
    set -l rust_cache "$TMPDIR/../C/com.Facepunch-Studios-LTD.Rust"

    if not test -e "$rust_cache"
        echo "Error: Rust cache not found: $rust_cache"
        return 1
    end

    command rm -rf -- "$rust_cache"
end

if command -q dig
    alias ip 'dig +short myip.opendns.com @resolver1.opendns.com || curl https://checkip.amazonaws.com'
else if command -q curl
    alias ip 'curl https://checkip.amazonaws.com'
end

if command -q lsof
    function ports -d "List listening TCP ports"
        if test (count $argv) -gt 1; or begin
                test (count $argv) -eq 1
                and not string match -qr '^[0-9]+$' -- $argv[1]
            end
            echo "Usage: ports [port]"
            return 1
        end

        if test (count $argv) -eq 0
            command lsof -nP -iTCP -sTCP:LISTEN
        else
            command lsof -nP -iTCP -sTCP:LISTEN | command grep -E "(:|\*)$argv[1]( |\$)"
        end
    end

    alias netcons 'lsof -i'
end
alias flushdns 'dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
if test -x /Applications/Tailscale.app/Contents/MacOS/Tailscale
    alias tailscale '/Applications/Tailscale.app/Contents/MacOS/Tailscale'
end

if command -q gsha256sum
    alias sha256sum gsha256sum
end

if command -q gsed
    alias sed gsed
end

if command -q gtar
    alias tar gtar
end

if command -q ggrep
    alias grep ggrep
end
