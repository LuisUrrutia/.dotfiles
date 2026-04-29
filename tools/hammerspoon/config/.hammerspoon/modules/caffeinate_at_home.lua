--[[
Caffeinate at Home Module for Hammerspoon
Prevents sleep and disables screensaver password when on home WiFi networks
--]]

local mod = {}

local log = hs.logger.new('caffeinate_at_home')

local screensaver = require('utils.screensaver')

local wifi_watcher = nil
local battery_watcher = nil
local home_SSIDs = {}
local home_SSID_set = {}

local function set_caffeinate(enabled)
    hs.caffeinate.set("systemIdle", enabled)
    hs.caffeinate.set("displayIdle", enabled)
end

local function is_on_ac_power()
    return hs.battery.powerSource() == "AC Power"
end

-- Handle WiFi change events
-- @return nil
local function on_wifi_change()
    local current_SSID = hs.wifi.currentNetwork() or ""

    local is_home = home_SSID_set[current_SSID] == true

    if is_home and is_on_ac_power() then
        log.i("On home WiFi: prevent sleep")

        set_caffeinate(true)
        screensaver.set_require_password(false)
    else
        log.i("Allow normal sleep. Current SSID: " .. current_SSID .. ", power: " .. hs.battery.powerSource())

        set_caffeinate(false)
        screensaver.set_require_password(true)
    end
end

local function normalize_SSIDs(SSIDs)
    if type(SSIDs) ~= "table" or #SSIDs == 0 then
        return nil
    end

    local SSID_set = {}
    for _, SSID in ipairs(SSIDs) do
        if type(SSID) ~= "string" or SSID == "" then
            return nil
        end

        SSID_set[SSID] = true
    end

    return SSID_set
end

-- Start the caffeinate at home mod
-- @param SSID string - The SSID of the home WiFi network
-- @return nil
function mod.start(SSIDs)
    local SSID_set = normalize_SSIDs(SSIDs)
    if not SSID_set then
        log.e("No SSIDs provided")
        return false
    end

    if wifi_watcher or battery_watcher then
        return true
    end

    log.i("Starting caffeinate at home mod with SSIDs: " .. table.concat(SSIDs, ", "))

    home_SSIDs = SSIDs
    home_SSID_set = SSID_set
    wifi_watcher = hs.wifi.watcher.new(on_wifi_change)
    wifi_watcher:start()
    battery_watcher = hs.battery.watcher.new(on_wifi_change)
    battery_watcher:start()

    -- Run once at startup
    on_wifi_change()

    return true
end

-- Stop the caffeinate at home mod
-- @return nil
function mod.stop()
    if wifi_watcher then
        wifi_watcher:stop()
        wifi_watcher = nil
    end

    if battery_watcher then
        battery_watcher:stop()
        battery_watcher = nil
    end

    home_SSIDs = {}
    home_SSID_set = {}
    set_caffeinate(false)
    screensaver.set_require_password(true)
end

return mod
