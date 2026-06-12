function hammer-restart -d "Restart Hammerspoon"
    echo "Restarting Hammerspoon..."
    pkill -9 -x Hammerspoon
    open /Applications/Hammerspoon.app
end
