complete --erase -c git_change_remote

complete -c git_change_remote -f -a ssh -d "Use SSH remote"
complete -c git_change_remote -f -a https -d "Use HTTPS remote"
