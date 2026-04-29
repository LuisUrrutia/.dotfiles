function cx -d "cd and list"
    if test (count $argv) -ne 1
        echo "Usage: cx <directory>"
        return 1
    end

    cd -- "$argv[1]"; and ll
end
