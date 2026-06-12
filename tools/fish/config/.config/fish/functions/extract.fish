function extract -d "Extract various archive formats"
    if test (count $argv) -ne 1
        echo "Usage: extract <archive_file>"
        return 1
    end

    set -l file $argv[1]

    if not test -f "$file"
        echo "Error: '$file' is not a valid file."
        return 1
    end

    set -l cmd
    switch "$file"
        case "*.tar.bz2" "*.tbz2"
            set cmd tar -xvjf
        case "*.tar.gz" "*.tgz"
            set cmd tar -xvzf
        case "*.tar.xz"
            set cmd tar -xvJf
        case "*.tar"
            set cmd tar -xvf
        case "*.bz2"
            set cmd bunzip2
        case "*.rar"
            set cmd rar x
        case "*.gz"
            set cmd gunzip
        case "*.zip"
            set cmd unzip
        case "*.Z"
            set cmd uncompress
        case "*.7z"
            set cmd 7z x
        case "*"
            echo "Error: unsupported archive format: '$file'"
            return 1
    end

    if not command -q $cmd[1]
        echo "Error: $cmd[1] not found."
        return 1
    end

    command $cmd "$file"
end
