--[[
Bluetooth Sleep Manager Module for Hammerspoon
Manages Bluetooth device connections during sleep/wake cycles
--]]

local mod = {}

local log = hs.logger.new('bluetooth_sleep_manager')
local bluetooth = require('utils.bluetooth')

-- Store addresses of devices that were connected before sleep
local previous_connected = {}
local reconnect_timer = nil

-- Caffeinate watcher instance
local caffeinate_watcher = nil

-- Handle sleep/wake events for Bluetooth devices
-- @param eventType number - Caffeinate event type constant
local function has_previous_connected()
    for _ in pairs(previous_connected) do
        return true
    end

    return false
end

local function reconnect_previous()
    if (not bluetooth.is_powered_on()) then
        return
    end

    log.i("Machine woke up: reconnecting Bluetooth devices")
    for address in pairs(previous_connected) do
        bluetooth.connect(address)
    end

    previous_connected = {}
    reconnect_timer = nil
end

local function watch(eventType)
    if (eventType == hs.caffeinate.watcher.systemWillSleep) then
        -- Store and disconnect all currently connected devices
        -- when the machine goes to sleep

        if (not bluetooth.is_powered_on()) then
            return
        end

        if has_previous_connected() then
            return
        end

        log.i("Machine is going to sleep: disconnecting all Bluetooth devices")
        local devices = bluetooth.connected_devices()
        for _, device in ipairs(devices) do
            if not previous_connected[device.address] then
                previous_connected[device.address] = true
                bluetooth.disconnect(device.address)
            end
        end

    elseif (eventType == hs.caffeinate.watcher.systemDidWake) then
        -- Reconnect all previously connected devices
        -- when the machine wakes up
        if has_previous_connected() and not reconnect_timer then
            reconnect_timer = hs.timer.doAfter(2, reconnect_previous)
        end
    end
end

-- Start the Bluetooth sleep manager
-- @return nil
function mod.start()
    if caffeinate_watcher then
        return
    end

    log.i("Starting Bluetooth sleep manager")

    caffeinate_watcher = hs.caffeinate.watcher.new(watch)
    caffeinate_watcher:start()
end

-- Stop the Bluetooth sleep manager
-- @return nil
function mod.stop()
    if reconnect_timer then
        reconnect_timer:stop()
        reconnect_timer = nil
    end

    if caffeinate_watcher then
        caffeinate_watcher:stop()
        caffeinate_watcher = nil
    end

    previous_connected = {}
end

return mod
