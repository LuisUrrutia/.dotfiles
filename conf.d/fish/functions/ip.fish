function ip -d "Print the public IP of this machine"
    argparse --max-args=0 -n ip h/help -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: ip [--help]"
        printf '%s\n' ""
        printf '%s\n' "Print the public IP address of this machine."
        printf '\n%s\n' Options
        printf '  %-12s %s\n' --help "show this help"
        return
    end

    # dig exits 0 with empty output on NXDOMAIN or a filtered resolver, so the
    # fallback has to key off the answer rather than the exit status.
    if command -q dig
        set -l answer (command dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
        if test -n "$answer"
            printf '%s\n' $answer[-1]
            return
        end
    end

    if not command -q curl
        echo "ip: no public IP from dig and curl is not available" >&2
        return 1
    end

    command curl -fsS https://checkip.amazonaws.com
end
