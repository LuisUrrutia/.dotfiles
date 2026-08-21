status is-interactive; or return

if command -q eza
    alias ls 'eza --icons=auto --color=auto --group-directories-first --octal-permissions'
    alias ll 'ls --git -alh --classify=auto'
    alias tree 'ls --tree'
end

if command -q nvim
    alias vim nvim
end

if command -q uvx
    for frida_tool in frida frida-ls frida-trace frida-ps frida-discover frida-kill frida-pull frida-push frida-ls-devices
        alias $frida_tool "uvx --from frida-tools $frida_tool"
    end

    alias llama "uvx --from llama-stack llama"
end

if command -q lsof
    alias netcons 'lsof -i'
end

# A real CLI in PATH wins; the app bundle is only the fallback.
if not command -q tailscale; and test -x /Applications/Tailscale.app/Contents/MacOS/Tailscale
    alias tailscale '/Applications/Tailscale.app/Contents/MacOS/Tailscale'
end

if command -q gsha256sum
    alias sha256sum gsha256sum
end

if command -q gsed
    alias sed gsed
end

if command -q ggrep
    alias grep ggrep
end
