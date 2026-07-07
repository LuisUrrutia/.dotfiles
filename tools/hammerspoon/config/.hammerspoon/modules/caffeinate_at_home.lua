--[[
Caffeinate at Home Module for Hammerspoon
Prevents sleep when on home WiFi networks and AC power
--]]

local mod = {}

---@type { d: fun(message: string), i: fun(message: string), w: fun(message: string), e: fun(message: string) }
local log = hs.logger.new('caffeinate_at_home')

-- WiFi transitions briefly report a nil SSID; wait this long before
-- treating a nil SSID as a real network change
local WIFI_SETTLE_DELAY = 5

local wifi_watcher = nil
local battery_watcher = nil
local wake_watcher = nil
local settle_timer = nil
local home_SSID_set = {}

local function set_caffeinate(enabled)
    hs.caffeinate.set("systemIdle", enabled)
    hs.caffeinate.set("displayIdle", enabled)
end

local function is_on_ac_power()
    return hs.battery.powerSource() == "AC Power"
end

local function request_location_services()
    local status = hs.location.authorizationStatus()
    if status ~= "authorized" then
        log.w("Location Services status is " .. status .. "; macOS may hide the current WiFi SSID from Hammerspoon")
    end

    hs.location.get()
end

-- Apply caffeinate state for the current WiFi network and power source
-- @return nil
local function evaluate()
    local current_SSID = hs.wifi.currentNetwork()
    local current_SSID_label = current_SSID or "<unavailable>"

    local is_home = home_SSID_set[current_SSID] == true

    if is_home and is_on_ac_power() then
        log.i("On home WiFi: prevent sleep")

        set_caffeinate(true)
    else
        if not current_SSID then
            log.w("WiFi SSID unavailable. Check Hammerspoon Location Services permission.")
        end

        log.i("Allow normal sleep. Current SSID: " .. current_SSID_label .. ", power: " .. hs.battery.powerSource())

        set_caffeinate(false)
    end
end

-- Handle WiFi/power change events, debouncing transient nil SSIDs
-- @return nil
local function on_change()
    if settle_timer then
        settle_timer:stop()
        settle_timer = nil
    end

    if not hs.wifi.currentNetwork() then
        settle_timer = hs.timer.doAfter(WIFI_SETTLE_DELAY, function()
            settle_timer = nil
            evaluate()
        end)
        return
    end

    evaluate()
end

local function on_wake(event_type)
    if event_type == hs.caffeinate.watcher.systemDidWake then
        on_change()
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

-- Start the caffeinate at home mod; restarts with the new list if running
-- @param SSIDs table - The SSIDs of the home WiFi networks
-- @return boolean
function mod.start(SSIDs)
    local SSID_set = normalize_SSIDs(SSIDs)
    if not SSID_set then
        log.e("No SSIDs provided")
        return false
    end

    if wifi_watcher or battery_watcher or wake_watcher then
        log.i("Already running; restarting with new SSIDs")
        mod.stop()
    end

    log.i("Starting caffeinate at home mod with SSIDs: " .. table.concat(SSIDs, ", "))

    request_location_services()

    home_SSID_set = SSID_set
    wifi_watcher = hs.wifi.watcher.new(on_change)
    wifi_watcher:start()
    battery_watcher = hs.battery.watcher.new(on_change)
    battery_watcher:start()
    wake_watcher = hs.caffeinate.watcher.new(on_wake)
    wake_watcher:start()

    -- Run once at startup
    on_change()

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

    if wake_watcher then
        wake_watcher:stop()
        wake_watcher = nil
    end

    if settle_timer then
        settle_timer:stop()
        settle_timer = nil
    end

    home_SSID_set = {}
    set_caffeinate(false)
end

return mod
