function mkd -d "Create a directory and set CWD"
    command mkdir -- $argv
    if test $status = 0
        set -l target $argv[(count $argv)]
        switch "$target"
            case '-*'
                return
            case '*'
                if test -d "$target"
                    cd "$target"
                end
                return
        end
    end
end
