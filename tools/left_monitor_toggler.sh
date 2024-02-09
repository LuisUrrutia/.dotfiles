#!/bin/sh
displayPort1=15
hdmi1=17
hdmi2=18

monitor="/usr/local/bin/ddcctl -d 3"

current=$(eval "${monitor} -i '?' | awk -F'[ ,]+' '/VCP control #/ {print \$(NF-2)}'")
if [ "$current" = "$hdmi2" ] || [ "$current" = "$hdmi1" ]; then
  eval "$monitor -i $displayPort1"
else
  eval "$monitor -i $hdmi2"
fi
