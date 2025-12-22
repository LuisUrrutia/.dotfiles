# Completion for awss command - sets AWS_PROFILE environment variable
complete -c awss -f -a '(aws configure list-profiles 2>/dev/null)'
