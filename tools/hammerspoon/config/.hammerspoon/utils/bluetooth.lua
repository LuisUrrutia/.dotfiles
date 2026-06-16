--[[
Bluetooth utility library for Hammerspoon
Provides functions to control Bluetooth devices via blueutil command
--]]

local lib = {}

-- Path to blueutil executable
local blueutil_path = "/opt/homebrew/bin/blueutil"

---@type fun(command: string, with_user_env?: boolean): string, boolean
local execute = hs.execute

local function valid_device_id(device_id)
    return type(device_id) == "string" and device_id:match("^%x%x[:-]%x%x[:-]%x%x[:-]%x%x[:-]%x%x[:-]%x%x$") ~= nil
end

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

-- Execute blueutil command and return output and status
-- @param command string - Command arguments to pass to blueutil
-- @return string, boolean - Command output and success status
local function blueutil(command)
    local output, status = execute(blueutil_path .. " " .. command, false)
    return output, status
end

-- Trigger macOS Bluetooth permission for blueutil without changing device state
-- @return boolean
function lib.request_permission()
    local _, status = blueutil("--paired")
    return status == true
end

-- Get list of connected Bluetooth devices
-- @return table - Array of connected device objects
function lib.connected_devices()
    local output, status = blueutil("--connected --format json")
    if not status then
        return {}
    end

    local ok, devices = pcall(hs.json.decode, output)
    if not ok or type(devices) ~= "table" then
        return {}
    end

    return devices
end

-- Check if specific device is connected
-- @param device_id string
-- @return boolean
function lib.is_connected(device_id)
    if not valid_device_id(device_id) then
        return false
    end

    local output, status = blueutil("--is-connected " .. shell_quote(device_id))
    if not status then
        return false
    end

    output = output:gsub("%s+", "")

    return output == "1"
end

-- Check if Bluetooth is powered on
-- @return boolean
function lib.is_powered_on()
    local output, status = blueutil("-p")
    if not status then
        return false
    end

    output = output:gsub("%s+", "")

    return output == "1"
end

-- Connect to Bluetooth device
-- @param device_id string - Bluetooth device address
-- @return nil
function lib.connect(device_id)
    if not valid_device_id(device_id) then
        return false
    end

    local _, status = blueutil("--connect " .. shell_quote(device_id))
    return status == true
end

-- Disconnect from Bluetooth device
-- @param device_id string - Bluetooth device address
-- @return nil
function lib.disconnect(device_id)
    if not valid_device_id(device_id) then
        return false
    end

    local _, status = blueutil("--disconnect " .. shell_quote(device_id))
    return status == true
end

return lib
