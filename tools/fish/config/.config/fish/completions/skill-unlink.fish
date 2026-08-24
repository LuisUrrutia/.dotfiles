complete --erase -c skill-unlink

complete -c skill-unlink -f -a '(__fish_complete_directories)' -d "Skill directory"
complete -c skill-unlink -s h -l help -d "Show help"
