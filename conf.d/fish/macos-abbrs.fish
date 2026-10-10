status is-interactive; or return

abbr -a -- localip 'ipconfig getifaddr en0'
abbr -a -- captive 'open -a Safari http://captive.apple.com'
abbr -a -- icloud 'cd "$HOME/Library/Mobile Documents/com~apple~CloudDocs"'
abbr -a -- obsidian 'cd "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"'

# A real CLI in PATH wins; the app bundle is only the fallback.
if not command -q tailscale; and test -x /Applications/Tailscale.app/Contents/MacOS/Tailscale
    abbr -a -- tailscale '/Applications/Tailscale.app/Contents/MacOS/Tailscale'
end
