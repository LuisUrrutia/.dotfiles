# WIP: toogle monitors for second computer
displayPort1=15
hdmi1=17
hdmi2=18

left_monitor="ddcctl -d 3"
middle_monitor="ddcctl -d 1"
right_monitor="ddcctl -d 2"

function get_current_source() {
  local monitor=$1
  local result=$(eval "$monitor -i '?' | awk -F'[ ,]+' '/VCP control #/ {print \$(NF-2)}'")
  echo "$result"
}

function toggle_left_monitor() {
  local current=$(get_current_source $left_monitor)
  if [ "$current" -eq "$hdmi2" ] || [ "$current" -eq "$hdmi1" ]; then
    eval "$left_monitor -i $displayPort1"
  else
    eval "$left_monitor -i $hdmi2"
  fi
}

function toggle_center_monitor() {
  local current=$(get_current_source $middle_monitor)
  if [ "$current" -eq "$hdmi2" ] || [ "$current" -eq "$hdmi1" ]; then
    eval "$middle_monitor -i $displayPort1"
  else
    eval "$middle_monitor -i $hdmi1"
  fi
}

