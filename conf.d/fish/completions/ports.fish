complete --erase -c ports

complete -c ports -f -a '(__fish_listening_ports --describe)' -d "Listening TCP port"
