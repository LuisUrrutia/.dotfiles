function extract -d "Extract various archive formats"
    if test (count $argv) -eq 0
        echo "Usage: extract <archive_file>"
        return 1
    end

    set file $argv[1]

    if test -f "$file"
        switch "$file"
            case "*.tar.bz2"
                tar -xvjf "$file"
            case "*.tar.gz"
                tar -xvzf "$file"
            case "*.tar.xz"
                tar -xvJf "$file"
            case "*.bz2"
                bunzip2 "$file"
            case "*.rar"
                rar x "$file"
            case "*.gz"
                gunzip "$file"
            case "*.tar"
                tar -xvf "$file"
            case "*.tbz2"
                tar -xvjf "$file"
            case "*.tgz"
                tar -xvzf "$file"
            case "*.zip"
                unzip "$file"
            case "*.Z"
                uncompress "$file"
            case "*.7z"
                7z x "$file"
            case "*"
                echo "don't know how to extract '$file'..."
        end
    else
        echo "'$file' is not a valid file!"
    end
end
