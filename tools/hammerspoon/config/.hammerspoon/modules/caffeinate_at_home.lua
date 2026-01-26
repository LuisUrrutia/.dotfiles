--[[
Caffeinate at Home Module for Hammerspoon
Prevents sleep and disables screensaver password when on home WiFi networks
--]]

local mod = {}

local log = hs.logger.new('caffeinate_at_home')

local screensaver = require('utils.screensaver')

local wifi_watcher = nil
local home_SSIDs = {}

-- Handle WiFi change events
-- @return nil
local function on_wifi_change()
    local current_SSID = hs.wifi.currentNetwork() or ""

    local is_home = false
    for _, SSID in ipairs(home_SSIDs) do
        if current_SSID == SSID then
            is_home = true
            break
        end
    end

    if is_home then
        log.i("On home WiFi: prevent sleep")

        hs.caffeinate.set("systemIdle", true, true)
        hs.caffeinate.set("displayIdle", true, true)
        screensaver.set_require_password(false)
    else
        log.i("On other WiFi: allow normal sleep. Current SSID: " .. current_SSID)

        hs.caffeinate.set("systemIdle", false, true)
        hs.caffeinate.set("displayIdle", false, true)
        screensaver.set_require_password(true)
    end
end

-- Start the caffeinate at home mod
-- @param SSID string - The SSID of the home WiFi network
-- @return nil
function mod.start(SSIDs)
    if #SSIDs == 0 then
        log.e("No SSIDs provided")
        return
    end

    -- Hack to force location services to be enabled
    hs.location.start()
    hs.location.get()
    hs.location.stop()

    log.i("Starting caffeinate at home mod with SSIDs: " .. table.concat(SSIDs, ", "))

    home_SSIDs = SSIDs
    wifi_watcher = hs.wifi.watcher.new(on_wifi_change)
    wifi_watcher:start()

    -- Run once at startup
    on_wifi_change()
end

-- Stop the caffeinate at home mod
-- @return nil
function mod.stop()
    if wifi_watcher then
        wifi_watcher:stop()
        wifi_watcher = nil
    end

    home_SSIDs = {}
end

return mod
