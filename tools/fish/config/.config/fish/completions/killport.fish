complete --erase -c killport

complete -c killport -f -s n -l dry-run -d "Show listening processes and the TERM that would be sent"
complete -c killport -f -s y -l yes -d "Send TERM without prompting"
complete -c killport -f -s h -l help -d "Show help"
complete -c killport -f -a '(__fish_listening_ports --describe)' -d "Listening TCP port"
