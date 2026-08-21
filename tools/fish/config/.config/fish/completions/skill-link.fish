complete --erase -c skill-link

complete -c skill-link -f -a '(__fish_complete_directories)' -d "Skill directory"
complete -c skill-link -s h -l help -d "Show help"
