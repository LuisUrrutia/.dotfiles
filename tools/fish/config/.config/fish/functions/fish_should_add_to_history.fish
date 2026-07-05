set -g fish_history_ignore_regex '^(zi|z|ll|cd|ls|history|btop|clear|reset)(\s|$)'

function fish_should_add_to_history -d "Skip noisy commands from history"
    string match -qr "$fish_history_ignore_regex" -- $argv; and return 1
    return 0
end
