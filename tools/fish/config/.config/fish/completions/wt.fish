complete --erase -c wt

function __fish_worktrunk_complete
    set -l worktrunk_bin

    if set -q WORKTRUNK_BIN
        set worktrunk_bin $WORKTRUNK_BIN
    else
        set worktrunk_bin (type -P wt 2>/dev/null)
    end

    if test -n "$worktrunk_bin"
        env COMPLETE=fish "$worktrunk_bin" -- (commandline --current-process --tokenize --cut-at-cursor) (commandline --current-token) 2>/dev/null
    end
end

complete --keep-order --exclusive -c wt -f -a '(__fish_worktrunk_complete)'
