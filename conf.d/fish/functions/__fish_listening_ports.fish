function __fish_listening_ports -d "List listening TCP ports as port, command, pid, address; --describe emits completion rows"
    argparse describe -- $argv
    or return

    command -q lsof; or return 1

    command lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | command awk -v describe="$_flag_describe" '
        NR > 1 {
            split($9, address, ":")
            port = address[length(address)]
            if (port !~ /^[0-9]+$/) next
            if (describe) printf "%s\t%s (%s)\n", port, $1, $2
            else printf "%s\t%s\t%s\t%s\n", port, $1, $2, $9
        }' | command sort -n -u
end
