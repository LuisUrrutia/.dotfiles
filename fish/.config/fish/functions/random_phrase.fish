function random_phrase
    # Define arrays of phrases
    set short_phrases \
        "Change is the only constant" \
        "Stay hungry, stay foolish" \
        "Failure teaches success" \
        "Think big, start small" \
        "Practice makes perfect" \
        "Keep your commitments" \
        "Knowledge is power" \
        "Grow 1% every day"

    set long_phrases \
        "Be productive early. Do not fuck around all day" \
        "Be fucking practical. Success is not a theory" \
        "Stop bullshitting. It is fucking embarrassing" \
        "Care about the process, not just the outcome" \
        "Acquire new knowledge and always ask why" \
        "Hope for the best, prepare for the worst" \
        "Keep it simple, stupid (KISS principle)" \
        "Do the fucking work. Do not be lazy" \
        "Stop fucking waiting. It is time" \
        "Actions speak louder than words" \
        "Fail by action, not inaction"

    set cols (tput cols)

    set phrases_to_use
    if test $cols -lt 90
        set phrases_to_use $short_phrases
    else
        set phrases_to_use $short_phrases $long_phrases
    end

    set random_phrase (printf "%s\n" $phrases_to_use | shuf -n 1)

    figlet -w $cols "$random_phrase" | lolcrab -g cool
end
