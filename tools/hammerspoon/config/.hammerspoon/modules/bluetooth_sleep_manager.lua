--[[
Bluetooth Sleep Manager Module for Hammerspoon
Manages Bluetooth device connections during sleep/wake cycles
--]]

local mod = {}

local log = hs.logger.new('bluetooth_sleep_manager')
local bluetooth = require('utils.bluetooth')

-- How long to wait after wake (and between retries) before reconnecting
local RECONNECT_DELAY = 2
-- Give up reconnecting after this many failed attempts per wake
local MAX_RECONNECT_ATTEMPTS = 5

-- Store addresses of devices that were connected before sleep
local previous_connected = {}
local reconnect_timer = nil
local reconnect_attempts = 0

-- Caffeinate watcher instance
local caffeinate_watcher = nil

local reconnect_previous

local function has_previous_connected()
    return next(previous_connected) ~= nil
end

local function retry_or_give_up(reason)
    reconnect_attempts = reconnect_attempts + 1

    if reconnect_attempts >= MAX_RECONNECT_ATTEMPTS then
        log.w(reason .. "; giving up after " .. reconnect_attempts .. " attempts")
        previous_connected = {}
        reconnect_attempts = 0
        return
    end

    log.w(reason .. "; retrying in " .. RECONNECT_DELAY .. "s")
    reconnect_timer = hs.timer.doAfter(RECONNECT_DELAY, reconnect_previous)
end

-- Drop devices that reconnected; retry the rest until attempts run out
local function verify_reconnect()
    reconnect_timer = nil

    if not has_previous_connected() then
        reconnect_attempts = 0
        return
    end

    retry_or_give_up("Some Bluetooth devices failed to reconnect")
end

reconnect_previous = function()
    reconnect_timer = nil

    if not bluetooth.is_powered_on() then
        retry_or_give_up("Machine woke up but Bluetooth is not powered on")
        return
    end

    log.i("Machine woke up: reconnecting Bluetooth devices")

    local addresses = {}
    for address in pairs(previous_connected) do
        table.insert(addresses, address)
    end

    for _, address in ipairs(addresses) do
        bluetooth.connect(address, function(ok)
            if ok then
                previous_connected[address] = nil
            end
        end)
    end

    -- Give the async connects time to settle before checking for stragglers
    reconnect_timer = hs.timer.doAfter(RECONNECT_DELAY, verify_reconnect)
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
            reconnect_attempts = 0
            reconnect_timer = hs.timer.doAfter(RECONNECT_DELAY, reconnect_previous)
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
    bluetooth.request_permission()

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
    reconnect_attempts = 0
end

return mod
