function awss -d "Set AWS profile environment variable"
    if not command -q aws
        echo "Error: aws CLI not found."
        return 1
    end

    set -l profiles (aws configure list-profiles 2>/dev/null)

    if test (count $argv) -eq 0
        echo "Usage: awss <profile_name>"
        echo "Available profiles:"
        printf "%s\n" $profiles
        return 1
    end

    if test (count $argv) -ne 1
        echo "Usage: awss <profile_name>"
        return 1
    end

    if test (count $profiles) -gt 0; and not contains -- $argv[1] $profiles
        echo "Error: AWS profile '$argv[1]' not found."
        return 1
    end

    set -gx AWS_PROFILE $argv[1]
    echo "Using AWS_PROFILE=$AWS_PROFILE"
end
