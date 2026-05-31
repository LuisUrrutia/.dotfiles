function cb -d 'Gets or sets the system clipboard content'
    # If we are likely not the start of a pipeline then read stdin into the
    # clipboard.
    if not isatty stdin
        fish_clipboard_copy 2>/dev/null
    end

    # Always echo the current value of the clipboard.
    fish_clipboard_paste | cat -
end
