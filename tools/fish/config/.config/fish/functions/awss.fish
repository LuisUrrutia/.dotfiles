function awss -d "Set AWS profile environment variable"
    if test (count $argv) -eq 0
        echo "Usage: awss <profile_name>"
        echo "Available profiles:"
        aws configure list-profiles 2>/dev/null
        return 1
    end

    set -gx AWS_PROFILE $argv[1]
    echo "Using AWS_PROFILE=$argv[1]"
end
