complete --erase -c awss

function __fish_awss_profiles
    command -q aws; or return
    aws configure list-profiles 2>/dev/null | string replace -r '^(.*)$' '$1\tAWS profile'
end

complete -c awss -f -a '(__fish_awss_profiles)'
