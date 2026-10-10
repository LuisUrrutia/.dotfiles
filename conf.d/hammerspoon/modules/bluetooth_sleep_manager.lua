--[[
Disconnect Bluetooth devices on lid close and reconnect them on lid open.
--]]

local mod = {}

local log = hs.logger.new('bluetooth_sleep_manager')
local bluetooth = require('utils.bluetooth')

local RECONNECT_DELAY = 2
local MAX_RECONNECT_ATTEMPTS = 5
local RECONNECT_TIMEOUT = 10
local LID_CHECK_INTERVAL = 2

local previous_connected = {}
local reconnect_timer = nil
local reconnect_attempts = 0
local pending_connections = {}
local reconnect_wait = 0

local caffeinate_watcher = nil
local lid_timer = nil
local lid_closed = nil

local reconnect_previous

local function read_lid_closed()
    local output, ok = hs.execute("/usr/sbin/ioreg -r -n IOPMrootDomain -d 1 -l", false)
    if not ok then return nil end

    local state = output:match('"AppleClamshellState"%s*=%s*(%a+)')
    if state == "Yes" then return true end
    if state == "No" then return false end
    return nil
end

local function stop_reconnect_timer()
    if reconnect_timer then
        reconnect_timer:stop()
        reconnect_timer = nil
    end
end

local function cancel_pending_connections()
    local connections = pending_connections
    pending_connections = {}
    for _, connection in pairs(connections) do
        if connection.task then
            connection.task:terminate()
        end
    end
end

local function schedule_reconnect(callback)
    stop_reconnect_timer()
    reconnect_timer = hs.timer.doAfter(RECONNECT_DELAY, callback)
end

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
    schedule_reconnect(reconnect_previous)
end

-- Drop devices that reconnected; retry the rest until attempts run out
local function verify_reconnect()
    reconnect_timer = nil

    if next(pending_connections) then
        reconnect_wait = reconnect_wait + RECONNECT_DELAY
        if reconnect_wait < RECONNECT_TIMEOUT then
            schedule_reconnect(verify_reconnect)
            return
        end

        cancel_pending_connections()
    end

    if not has_previous_connected() then
        reconnect_attempts = 0
        return
    end

    retry_or_give_up("Some Bluetooth devices failed to reconnect")
end

reconnect_previous = function()
    reconnect_timer = nil

    if read_lid_closed() ~= false then
        retry_or_give_up("Lid is closed or its state is unavailable")
        return
    end

    if not bluetooth.is_powered_on() then
        retry_or_give_up("Lid opened but Bluetooth is not powered on")
        return
    end

    log.i("Lid opened: reconnecting Bluetooth devices")
    reconnect_wait = 0

    local addresses = {}
    for address in pairs(previous_connected) do
        table.insert(addresses, address)
    end

    for _, address in ipairs(addresses) do
        local connection = {}
        pending_connections[address] = connection
        connection.task = bluetooth.connect(address, function(ok)
            -- A cancelled attempt cannot modify a later lid cycle.
            if pending_connections[address] ~= connection then
                return
            end

            pending_connections[address] = nil
            if ok then
                previous_connected[address] = nil
            end
        end)
    end

    -- Give the async connects time to settle before checking for stragglers
    schedule_reconnect(verify_reconnect)
end

local function check_lid()
    local closed = read_lid_closed()
    if closed == nil or closed == lid_closed then return end
    lid_closed = closed

    if closed then
        stop_reconnect_timer()
        cancel_pending_connections()
        reconnect_attempts = 0

        if (not bluetooth.is_powered_on()) then
            return
        end

        log.i("Lid closed: disconnecting all Bluetooth devices")
        local devices = bluetooth.connected_devices()
        local disconnected = {}
        for _, device in ipairs(devices) do
            if not disconnected[device.address] then
                disconnected[device.address] = true
                previous_connected[device.address] = true
                bluetooth.disconnect(device.address)
            end
        end

    else
        if has_previous_connected() and not reconnect_timer then
            reconnect_attempts = 0
            schedule_reconnect(reconnect_previous)
        end
    end
end

local function watch(eventType)
    if eventType == hs.caffeinate.watcher.systemWillSleep
        or eventType == hs.caffeinate.watcher.systemDidWake
        or eventType == hs.caffeinate.watcher.screensDidSleep
        or eventType == hs.caffeinate.watcher.screensDidWake then
        check_lid()
    end
end

function mod.start()
    if caffeinate_watcher then
        return
    end

    log.i("Starting Bluetooth lid manager")
    bluetooth.request_permission()
    -- Reloading while docked must not disconnect the active keyboard or mouse.
    lid_closed = read_lid_closed()

    caffeinate_watcher = hs.caffeinate.watcher.new(watch)
    caffeinate_watcher:start()
    -- A lid close with an external display may not produce any sleep event.
    lid_timer = hs.timer.doEvery(LID_CHECK_INTERVAL, check_lid)
end

function mod.stop()
    stop_reconnect_timer()
    cancel_pending_connections()

    if caffeinate_watcher then
        caffeinate_watcher:stop()
        caffeinate_watcher = nil
    end

    if lid_timer then
        lid_timer:stop()
        lid_timer = nil
    end

    lid_closed = nil
    previous_connected = {}
    reconnect_attempts = 0
end

return mod
