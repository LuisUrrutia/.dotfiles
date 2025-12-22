local lib = {}

function lib.set_require_password(enabled)
    local on = enabled and 1 or 0

    hs.execute(string.format("/usr/bin/defaults write com.apple.screensaver askForPassword -int %d", on))
    hs.execute("/usr/bin/killall cfprefsd >/dev/null 2>&1 || true")
end

return lib