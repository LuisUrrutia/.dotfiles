set HISTIGNORE '^(zi|ll|cd|ls|history|btop|clear|reset)(\s|\$)'

function fish_should_add_to_history
	string match -qr "$HISTIGNORE" -- $argv; and return 1
      return 0
end