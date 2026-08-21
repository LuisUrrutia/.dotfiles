function f -d "Open Finder at a path (default: current directory)"
    set -l target .

    if test (count $argv) -gt 0
        set target $argv
    end

    command open -a Finder -- $target
end
