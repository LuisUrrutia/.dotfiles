function cb -d 'Gets or sets the system clipboard content'
    if test (count $argv) -gt 0
        command cat -- $argv | fish_clipboard_copy 2>/dev/null
        set -l copy_status $pipestatus

        for status_code in $copy_status
            test $status_code -eq 0; or return 1
        end

        fish_clipboard_paste | cat -
        return
    end

    # If we are likely not the start of a pipeline then read stdin into the
    # clipboard.
    if not isatty stdin
        fish_clipboard_copy 2>/dev/null; or return 1
    end

    # Always echo the current value of the clipboard.
    fish_clipboard_paste | cat -
end
