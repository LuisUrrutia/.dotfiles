
set window (yabai -m query --windows --space | jq -r '[.[]|select(."is-visible" and .layer != "unknown")][0].id')
yabai -m window --focus $window
