function git_change_remote -d "Change git remote between SSH and HTTPS protocols"
    # Usage: git_change_remote [ssh|https]
    # Default behavior: toggles between ssh and https

    # Get current remote URL
    set url (git remote get-url origin 2>/dev/null)
    if test -z "$url"
        echo "Error: Could not retrieve remote URL. Are you inside a Git repository?"
        return 1
    end

    # Determine current protocol and set target protocol
    if test "$argv[1]" = "ssh"; or test "$argv[1]" = "https"
        set target_proto $argv[1]
    else
        # Extract protocol from URL
        switch "$url"
            case "https://*"
                set current_proto "https"
                set target_proto "ssh"
            case "git@*"
                set current_proto "ssh"
                set target_proto "https"
            case "*"
                echo "Error: Unknown URL format: $url"
                return 1
        end
    end

    # Check if already using the target protocol
    switch "$url"
        case "$target_proto*"
            echo "Already using $target_proto protocol."
            return 0
    end

    # Convert the URL to the target protocol
    if test "$target_proto" = "ssh"
        # Convert HTTPS to SSH
        set new_url (printf '%s\n' "$url" | sed -E 's#https://([^/]+)/(.+)#git@\1:\2#')
    else
        # Convert SSH to HTTPS
        set new_url (printf '%s\n' "$url" | sed -E 's#git@([^:]+):(.+)#https://\1/\2#')
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
