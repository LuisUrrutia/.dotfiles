function fish_greeting -d "Show the interactive shell greeting"
    if test "$TERM_PROGRAM" = vscode; or test "$TERM_PROGRAM" = zed; or test -n "$TMUX"
        return 0
    end

    random_phrase
end
