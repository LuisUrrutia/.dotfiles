--[[
Bluetooth Sleep Manager Module for Hammerspoon
Manages Bluetooth device connections during sleep/wake cycles
--]]

local mod = {}

local log = hs.logger.new('bluetooth_sleep_manager')
local bluetooth = require('utils.bluetooth')

-- Store addresses of devices that were connected before sleep
local previous_connected = {}

-- Caffeinate watcher instance
local caffeinate_watcher = nil

-- Handle sleep/wake events for Bluetooth devices
-- @param eventType number - Caffeinate event type constant
local function watch(eventType)
    if (eventType == hs.caffeinate.watcher.screensDidSleep) then
        -- Store and disconnect all currently connected devices
        -- when the machine goes to sleep

        if (not bluetooth.is_powered_on()) then
            return
        end

        log.i("Machine is going to sleep: disconnecting all Bluetooth devices")
        local devices = bluetooth.connected_devices()
        for _, device in ipairs(devices) do
            table.insert(previous_connected, device.address)
            bluetooth.disconnect(device.address)
        end

    elseif (eventType == hs.caffeinate.watcher.screensDidWake) then
        -- Reconnect all previously connected devices
        -- when the machine wakes up

        if (not bluetooth.is_powered_on()) then
            return
        end

        log.i("Machine is waking up: reconnecting all Bluetooth devices")
        for _, device in ipairs(previous_connected) do
            bluetooth.connect(device)
        end

        previous_connected = {}
    end
end

-- Start the Bluetooth sleep manager
-- @return nil
function mod.start()
    log.i("Starting Bluetooth sleep manager")
    
    caffeinate_watcher = hs.caffeinate.watcher.new(watch)
    caffeinate_watcher:start()
end

-- Stop the Bluetooth sleep manager
-- @return nil
function mod.stop()
    if caffeinate_watcher then
        caffeinate_watcher:stop()
        caffeinate_watcher = nil
    end
end

return mod
