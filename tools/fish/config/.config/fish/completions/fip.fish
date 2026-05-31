complete --erase -c fip

function __fish_fip_ports
    printf '%s\t%s\n' 3000 "Rails, Node, Next.js"
    printf '%s\t%s\n' 5173 Vite
    printf '%s\t%s\n' 8000 "HTTP dev server"
    printf '%s\t%s\n' 8080 "HTTP alternate"
    printf '%s\t%s\n' 5432 PostgreSQL
    printf '%s\t%s\n' 6379 Redis
end

complete -c fip -f -s h -l help -d "Show help"
complete -c fip -f -s l -l list -d "List active SSH local forwards"
complete -c fip -f -n 'test (count (commandline -opc)) -eq 1' -a '(__fish_print_hostnames)' -d "SSH host"
complete -c fip -f -n 'test (count (commandline -opc)) -ge 2' -a '(__fish_fip_ports)' -d "Local port"
