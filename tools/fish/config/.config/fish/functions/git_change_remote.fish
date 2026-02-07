function git_change_remote -d "Change git remote between SSH and HTTPS protocols"
    # Usage: git_change_remote [ssh|https]
    # Default behavior: toggles between ssh and https

    # Get current remote URL
    set -l url (git remote get-url origin 2>/dev/null)
    if test -z "$url"
        echo "Error: Could not retrieve remote URL. Are you inside a Git repository?"
        return 1
    end

    # Parse current URL into protocol, host and repo path.
    set -l current_proto
    set -l host
    set -l repo_path

    if string match -qr '^https://[^/]+/.+' -- "$url"
        set current_proto https
        set host (string replace -r '^https://([^/]+)/(.+)$' '$1' -- "$url")
        set repo_path (string replace -r '^https://([^/]+)/(.+)$' '$2' -- "$url")
    else if string match -qr '^git@[^:]+:.+' -- "$url"
        set current_proto ssh
        set host (string replace -r '^git@([^:]+):(.+)$' '$1' -- "$url")
        set repo_path (string replace -r '^git@([^:]+):(.+)$' '$2' -- "$url")
    else if string match -qr '^ssh://git@[^/]+/.+' -- "$url"
        set current_proto ssh
        set host (string replace -r '^ssh://git@([^/]+)/(.+)$' '$1' -- "$url")
        set repo_path (string replace -r '^ssh://git@([^/]+)/(.+)$' '$2' -- "$url")
    else
        echo "Error: Unsupported remote URL format: $url"
        return 1
    end

    # Determine target protocol.
    set -l target_proto
    if test (count $argv) -gt 0
        switch "$argv[1]"
            case ssh https
                set target_proto "$argv[1]"
            case '*'
                echo "Usage: git_change_remote [ssh|https]"
                return 1
        end
    else
        if test "$current_proto" = ssh
            set target_proto https
        else
            set target_proto ssh
        end
    end

    if test "$current_proto" = "$target_proto"
        echo "Already using $target_proto protocol."
        return 0
    end

    # Build new URL in the requested protocol.
    set -l new_url
    if test "$target_proto" = "ssh"
        set new_url "git@$host:$repo_path"
    else
        set new_url "https://$host/$repo_path"
    end

    # Set the new remote URL
    if test -n "$new_url"
        echo "Changing remote URL from:"
        echo "  $url"
        echo "to:"
        echo "  $new_url"
        git remote set-url origin "$new_url"
    else
        echo "Error: Failed to generate new URL."
        return 1
    end
end
