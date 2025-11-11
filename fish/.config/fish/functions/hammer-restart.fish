function hammer-restart -d "Restart Hammerspoon" 
    echo "Restarting Hammerspoon..."
    pkill -9 -f "Hammerspoon.app"
    open /Applications/Hammerspoon.app
end