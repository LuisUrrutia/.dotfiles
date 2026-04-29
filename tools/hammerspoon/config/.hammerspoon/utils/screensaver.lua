--[[
Screensaver utility library for Hammerspoon
Provides functions to control macOS screensaver settings
--]]

local lib = {}
local current_require_password = nil

-- Set whether password is required after screensaver
-- @param enabled boolean - Whether to require password
-- @return nil
function lib.set_require_password(enabled)
    if current_require_password == enabled then
        return
    end

    local on = enabled and 1 or 0
    local delay = enabled and 0 or 2147483647

    hs.execute(string.format("/usr/bin/defaults write com.apple.screensaver askForPassword -int %d", on))
    hs.execute(string.format("/usr/bin/defaults write com.apple.screensaver askForPasswordDelay -int %d", delay))
    hs.execute("/usr/bin/killall cfprefsd >/dev/null 2>&1 || true")
    current_require_password = enabled
end

return lib
