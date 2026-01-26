--[[
Screensaver utility library for Hammerspoon
Provides functions to control macOS screensaver settings
--]]

local lib = {}

-- Set whether password is required after screensaver
-- @param enabled boolean - Whether to require password
-- @return nil
function lib.set_require_password(enabled)
    local on = enabled and 1 or 0

    hs.execute(string.format("/usr/bin/defaults write com.apple.screensaver askForPassword -int %d", on))
    hs.execute("/usr/bin/killall cfprefsd >/dev/null 2>&1 || true")
end

return lib
