function random_phrase -d "Print a random motivational phrase"
    command -q figlet; or return 0
    command -q lolcrab; or return 0
    command -q shuf; or return 0
    command -q tput; or return 0

    set -l short_phrases \
        "Change is the only constant" \
        "Stay hungry, stay foolish" \
        "Failure teaches success" \
        "Think big, start small" \
        "Practice makes perfect" \
        "Keep your commitments" \
        "Knowledge is power" \
        "Grow 1% every day"

    set -l long_phrases \
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

    set -l cols (tput cols 2>/dev/null)
    test -n "$cols"; or set cols 80

    set -l phrases_to_use $short_phrases
    if test $cols -ge 90
        set phrases_to_use $short_phrases $long_phrases
    end

    set -l phrase (printf "%s\n" $phrases_to_use | shuf -n 1)
    figlet -w $cols "$phrase" | lolcrab -g cool
end
