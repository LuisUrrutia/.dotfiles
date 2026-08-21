complete --erase -c ports

function __fish_ports_listening
    command -q lsof; or return
    command lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | command awk '
        NR > 1 {
            split($9, address, ":")
            port = address[length(address)]
            if (port ~ /^[0-9]+$/) {
                printf "%s\t%s (%s)\n", port, $1, $2
            }
        }' | command sort -n -u
end

complete -c ports -f -a '(__fish_ports_listening)' -d "Listening TCP port"
