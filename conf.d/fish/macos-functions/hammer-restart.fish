function hammer-restart -d "Restart Hammerspoon"
    test (uname -s) = Darwin; or return 1
    echo "Restarting Hammerspoon..."
    pkill -9 -x Hammerspoon
    open /Applications/Hammerspoon.app
end
