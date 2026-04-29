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

    switch "$file"
        case "*.tar.bz2" "*.tbz2"
            command -q tar; or begin; echo "Error: tar not found."; return 1; end
            tar -xvjf "$file"
        case "*.tar.gz" "*.tgz"
            command -q tar; or begin; echo "Error: tar not found."; return 1; end
            tar -xvzf "$file"
        case "*.tar.xz"
            command -q tar; or begin; echo "Error: tar not found."; return 1; end
            tar -xvJf "$file"
        case "*.tar"
            command -q tar; or begin; echo "Error: tar not found."; return 1; end
            tar -xvf "$file"
        case "*.bz2"
            command -q bunzip2; or begin; echo "Error: bunzip2 not found."; return 1; end
            bunzip2 "$file"
        case "*.rar"
            command -q rar; or begin; echo "Error: rar not found."; return 1; end
            rar x "$file"
        case "*.gz"
            command -q gunzip; or begin; echo "Error: gunzip not found."; return 1; end
            gunzip "$file"
        case "*.zip"
            command -q unzip; or begin; echo "Error: unzip not found."; return 1; end
            unzip "$file"
        case "*.Z"
            command -q uncompress; or begin; echo "Error: uncompress not found."; return 1; end
            uncompress "$file"
        case "*.7z"
            command -q 7z; or begin; echo "Error: 7z not found."; return 1; end
            7z x "$file"
        case "*"
            echo "Error: unsupported archive format: '$file'"
            return 1
    end
end
