function fish_should_add_to_history -d "Skip standalone navigation and display commands from history"
    # Keep ambiguous shell syntax rather than discard useful commands.
    string match -qr '[;&|()<>\n]' -- "$argv[1]"; and return 0
    string match -qr '^(cdi|cd|ll|ls|history|btop|clear|reset)(\s|$)' -- "$argv[1]"; and return 1
    return 0
end
