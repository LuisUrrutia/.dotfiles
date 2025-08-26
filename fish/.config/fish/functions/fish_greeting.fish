function fish_greeting
    if test "$TERM_PROGRAM" != "vscode"; and test -z "$TMUX"
        random_phrase
    end
end