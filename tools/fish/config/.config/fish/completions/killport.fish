complete --erase -c killport

function __fish_killport_ports
    command -q lsof; or return
    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk '
        NR > 1 {
            split($9, address, ":")
            port = address[length(address)]
            if (port ~ /^[0-9]+$/) {
                printf "%s\t%s (%s)\n", port, $1, $2
            }
        }' | sort -n -u
end

complete -c killport -f -s n -l dry-run -d "Show listening processes and the TERM that would be sent"
complete -c killport -f -s y -l yes -d "Send TERM without prompting"
complete -c killport -f -s h -l help -d "Show help"
complete -c killport -f -a '(__fish_killport_ports)' -d "Listening TCP port"
