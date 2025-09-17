--[[
Bluetooth utility library for Hammerspoon
Provides functions to control Bluetooth devices via blueutil command
--]]

local lib = {}

-- Path to blueutil executable
local blueutil_path = "/opt/homebrew/bin/blueutil"

-- Execute blueutil command and return output and status
-- @param command string - Command arguments to pass to blueutil
-- @return string, boolean - Command output and success status
local function blueutil(command)
    local output, status, type, rc = hs.execute(blueutil_path .. " " .. command, false)
    return output, status
end

-- Get list of connected Bluetooth devices
-- @return table - Array of connected device objects
function lib.connected_devices()
    local output, status = blueutil("--connected --format json")
    return hs.json.decode(output)
end

-- Check if specific device is connected
-- @param device_id string
-- @return boolean
function lib.is_connected(device_id)
    local output, status = blueutil("--is-connected '" .. device_id .. "'")
    output = output:gsub("%s+", "")

    return output == "1"
end

-- Check if Bluetooth is powered on
-- @return boolean
function lib.is_powered_on()
    local output, status = blueutil("-p")
    output = output:gsub("%s+", "")

    return output == "1"
end

-- Connect to Bluetooth device
-- @param device_id string - Bluetooth device address
-- @return nil
function lib.connect(device_id)
    blueutil("--connect '" .. device_id .. "'")
end

-- Disconnect from Bluetooth device
-- @param device_id string - Bluetooth device address
-- @return nil
function lib.disconnect(device_id)
    blueutil("--disconnect '" .. device_id .. "'")
end

return lib