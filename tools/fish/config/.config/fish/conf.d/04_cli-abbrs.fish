status is-interactive; or return

if command -q eza
    abbr -a -- ls 'eza --icons=auto --color=auto --group-directories-first --octal-permissions'
    alias ll 'eza --icons=auto --color=auto --group-directories-first --octal-permissions --git -alh --classify=auto'
    abbr -a -- tree 'eza --icons=auto --color=auto --group-directories-first --octal-permissions --tree'
end

if command -q nvim
    abbr -a -- vim nvim
end

if command -q uvx
    for frida_tool in frida frida-ls frida-trace frida-ps frida-discover frida-kill frida-pull frida-push frida-ls-devices
        abbr -a -- $frida_tool "uvx --from frida-tools $frida_tool"
    end

    abbr -a -- llama "uvx --from llama-stack llama"
end

if command -q lsof
    abbr -a -- netcons 'lsof -i'
end

# A real CLI in PATH wins; the app bundle is only the fallback.
if not command -q tailscale; and test -x /Applications/Tailscale.app/Contents/MacOS/Tailscale
    abbr -a -- tailscale '/Applications/Tailscale.app/Contents/MacOS/Tailscale'
end

if command -q gsha256sum
    abbr -a -- sha256sum gsha256sum
end

if command -q gsed
    abbr -a -- sed gsed
end

if command -q ggrep
    abbr -a -- grep ggrep
end
