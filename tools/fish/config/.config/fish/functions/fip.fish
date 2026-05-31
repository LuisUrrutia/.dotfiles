function fip --description 'Forward localhost ports to remote host over SSH'
    argparse -n fip h/help l/list -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: fip <host> <port1> [port2] ..."
        printf '%s\n' "       fip --list"
        printf '%s\n' ""
        printf '%s\n' "Forward localhost ports to a remote host over SSH."
        printf '\n%s\n' Options
        printf '  %-12s %s\n' --list "list active SSH local forwards"
        printf '  %-12s %s\n' --help "show this help"
        printf '\n%s\n' Examples
        printf '  %s\n' "fip example.com 3000 5173"
        printf '  %s\n' "fip --list"
        return
    end

    if set -q _flag_list
        if test (count $argv) -ne 0
            echo "Usage: fip --list"
            return 1
        end

        pgrep -af "ssh.*-L (127[.]0[.]0[.]1:)?[0-9]+:localhost:[0-9]+"
        or echo "No active forwards"
        return
    end

    if test (count $argv) -lt 2
        echo "Usage: fip <host> <port1> [port2] ..."
        return 1
    end

    set -l host $argv[1]
    if string match -q -- '-*' "$host"
        echo "fip: host must not start with '-'" >&2
        return 1
    end

    for port in $argv[2..-1]
        if not string match -qr '^[0-9]+$' -- "$port"; or test "$port" -lt 1 -o "$port" -gt 65535
            echo "fip: port must be between 1 and 65535: $port" >&2
            return 1
        end
    end

    set -l failed 0
    for port in $argv[2..-1]
        if ssh -f -N -L "127.0.0.1:$port:localhost:$port" "$host"
            echo "Forwarding 127.0.0.1:$port -> $host:$port"
        else
            set failed 1
        end
    end

    return $failed
end
