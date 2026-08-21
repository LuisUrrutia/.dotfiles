function flushdns -d "Flush the macOS DNS cache"
    argparse --max-args=0 -n flushdns h/help -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: flushdns [--help]"
        printf '%s\n' ""
        printf '%s\n' "Flush the macOS DNS cache and restart the mDNS responder."
        printf '\n%s\n' Options
        printf '  %-12s %s\n' --help "show this help"
        return
    end

    if not command -q dscacheutil; or not command -q killall
        echo "flushdns: requires macOS dscacheutil and killall" >&2
        return 1
    end

    command dscacheutil -flushcache
    and sudo killall -HUP mDNSResponder
end
