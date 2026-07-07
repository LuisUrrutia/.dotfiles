local root = os.getenv("DOTFILES_TEST_ROOT") or (os.getenv("PWD") or ".")
package.path = root ..
"/tools/hammerspoon/config/.hammerspoon/?.lua;" ..
root .. "/tools/hammerspoon/config/.hammerspoon/?/init.lua;" .. package.path

local tests = {}

local function test(name, fn)
    table.insert(tests, { name = name, fn = fn })
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assert_truthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function assert_false(value, message)
    if value then
        error(message or "expected falsey value", 2)
    end
end

local function read_file(path)
    local file = assert(io.open(root .. "/" .. path, "r"))
    local contents = file:read("*a")
    file:close()
    return contents
end

local function unload_modules()
    for name in pairs(package.loaded) do
        if name == "bindings" or name:match("^modules%.") or name:match("^utils%.") then
            package.loaded[name] = nil
        end
    end
end

local function build_hs()
    local hs = {
        calls = {},
        logger = {},
        caffeinate = {
            watcher = {
                systemWillSleep = 1,
                systemDidWake = 2,
                screensDidSleep = 3,
                screensDidWake = 4,
            },
        },
        wifi = { watcher = {} },
        battery = { watcher = {} },
        location = {},
        timer = {},
        timers = {},
        hotkey = {},
        json = {},
        task = {},
        task_fail = {},
        fs = { files = { ["/opt/homebrew/bin/blueutil"] = true } },
        bluetooth_powered_on = true,
    }

    function hs.logger.new(name, level)
        table.insert(hs.calls, { type = "logger", name = name, level = level })
        return { d = function(...) end, i = function(...) end, w = function(...) end, e = function(...) end }
    end

    function hs.caffeinate.set(kind, value, ac_and_battery)
        table.insert(hs.calls, { type = "caffeinate_set", kind = kind, value = value, ac_and_battery = ac_and_battery })
    end

    function hs.caffeinate.watcher.new(fn)
        hs.caffeinate.watch_count = (hs.caffeinate.watch_count or 0) + 1
        hs.caffeinate.callback = fn
        return {
            start = function(self)
                self.started = true
                return self
            end,
            stop = function(self)
                self.stopped = true
                return self
            end,
        }
    end

    function hs.battery.powerSource()
        return hs.battery.source or "Battery Power"
    end

    function hs.battery.watcher.new(fn)
        hs.battery.watch_count = (hs.battery.watch_count or 0) + 1
        hs.battery.callback = fn
        return {
            start = function(self)
                self.started = true
                return self
            end,
            stop = function(self)
                self.stopped = true
                return self
            end,
        }
    end

    function hs.location.authorizationStatus()
        table.insert(hs.calls, { type = "location_status" })
        return hs.location.status or "authorized"
    end

    function hs.location.get()
        table.insert(hs.calls, { type = "location_get" })
        return hs.location.current
    end

    function hs.wifi.currentNetwork()
        table.insert(hs.calls, { type = "wifi_current_network" })
        return hs.wifi.current
    end

    function hs.wifi.watcher.new(fn)
        hs.wifi.watch_count = (hs.wifi.watch_count or 0) + 1
        hs.wifi.callback = fn
        return {
            start = function(self)
                self.started = true
                return self
            end,
            stop = function(self)
                self.stopped = true
                return self
            end,
        }
    end

    function hs.timer.doAfter(delay, fn)
        local timer = {
            stopped = false,
            fire = function(self)
                if not self.stopped then
                    fn()
                end
            end,
            stop = function(self)
                self.stopped = true
            end,
        }

        table.insert(hs.calls, { type = "timer", delay = delay, timer = timer })
        table.insert(hs.timers, timer)
        return timer
    end

    function hs.hotkey.bind(mods, key, fn)
        table.insert(hs.calls, { type = "hotkey", mods = mods, key = key, fn = fn })
    end

    function hs.execute(command, with_user_env)
        table.insert(hs.calls, { type = "execute", command = command, with_user_env = with_user_env })
        if command:find(" %-p") then
            if hs.bluetooth_powered_on then
                return "1\n", true, "exit", 0
            end

            return "0\n", true, "exit", 0
        end

        return "", true, "exit", 0
    end

    function hs.task.new(path, callback, arguments)
        return {
            start = function(self)
                table.insert(hs.calls, { type = "task", path = path, arguments = arguments })
                local exit_code = hs.task_fail[arguments[#arguments]] and 1 or 0
                if callback then
                    callback(exit_code, "", "")
                end
                return self
            end,
        }
    end

    function hs.fs.attributes(path, attribute)
        table.insert(hs.calls, { type = "fs_attributes", path = path, attribute = attribute })
        if hs.fs.files[path] then
            return "file"
        end
        return nil
    end

    function hs.json.decode(value)
        if value == "bad" then
            error("bad json")
        end
        return hs.json.next_value or {}
    end

    _G.hs = hs
    return hs
end

local function load_module(name)
    unload_modules()
    return require(name)
end

local function count_calls(hs, predicate)
    local count = 0
    for _, call in ipairs(hs.calls) do
        if predicate(call) then
            count = count + 1
        end
    end
    return count
end

local function count_disconnects(hs)
    return count_calls(hs, function(call)
        return call.type == "execute" and call.command:find("%-%-disconnect") ~= nil
    end)
end

local function count_connects(hs, address)
    return count_calls(hs, function(call)
        return call.type == "task" and call.arguments[1] == "--connect"
            and (address == nil or call.arguments[2] == address)
    end)
end

test("bluetooth manager uses system sleep events, dedupes devices, and delays reconnect", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-ff" },
        { address = "aa-bb-cc-dd-ee-ff" },
    }

    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")
    bluetooth_sleep_manager.start()

    hs.caffeinate.callback(hs.caffeinate.watcher.screensDidSleep)
    hs.caffeinate.callback(hs.caffeinate.watcher.systemWillSleep)
    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)
    hs.timers[1]:fire()
    hs.timers[2]:fire()

    assert_equal(count_disconnects(hs), 1, "system sleep should disconnect each device once")
    assert_equal(count_connects(hs), 1, "system wake should reconnect each device once")
    assert_equal(#hs.timers, 2, "wake should schedule a delayed reconnect and a settle check")
end)

test("bluetooth manager retries when Bluetooth is off after wake", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-ff" },
    }

    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")
    bluetooth_sleep_manager.start()

    hs.caffeinate.callback(hs.caffeinate.watcher.systemWillSleep)

    hs.bluetooth_powered_on = false
    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)
    hs.timers[1]:fire()

    assert_equal(#hs.timers, 2, "powered-off Bluetooth should schedule a retry")

    hs.bluetooth_powered_on = true
    hs.timers[2]:fire()
    hs.timers[3]:fire()

    assert_equal(count_connects(hs), 1, "retry should reconnect the remembered device")
    assert_equal(#hs.timers, 3, "successful reconnect should stop retrying")
end)

test("bluetooth manager gives up reconnecting after max attempts", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-ff" },
    }

    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")
    bluetooth_sleep_manager.start()

    hs.caffeinate.callback(hs.caffeinate.watcher.systemWillSleep)

    hs.bluetooth_powered_on = false
    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)

    local index = 1
    while hs.timers[index] do
        hs.timers[index]:fire()
        index = index + 1
    end

    assert_equal(#hs.timers, 5, "retries should stop after the attempt limit")
    assert_equal(count_connects(hs), 0, "no reconnect should run while Bluetooth is off")

    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)
    assert_equal(#hs.timers, 5, "given-up devices should not be retried on a later wake")
end)

test("bluetooth manager retries only devices that failed to reconnect", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-01" },
        { address = "aa-bb-cc-dd-ee-02" },
    }

    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")
    bluetooth_sleep_manager.start()

    hs.caffeinate.callback(hs.caffeinate.watcher.systemWillSleep)
    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)

    hs.task_fail["aa-bb-cc-dd-ee-01"] = true
    hs.timers[1]:fire()
    hs.timers[2]:fire()

    hs.task_fail["aa-bb-cc-dd-ee-01"] = nil
    hs.timers[3]:fire()
    hs.timers[4]:fire()

    assert_equal(count_connects(hs, "aa-bb-cc-dd-ee-01"), 2, "failed device should be retried")
    assert_equal(count_connects(hs, "aa-bb-cc-dd-ee-02"), 1, "connected device should not be retried")
    assert_equal(#hs.timers, 4, "retry loop should stop once every device reconnected")
end)

test("bluetooth manager start is idempotent", function()
    local hs = build_hs()
    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")

    bluetooth_sleep_manager.start()
    bluetooth_sleep_manager.start()

    assert_equal(hs.caffeinate.watch_count, 1, "start should create one watcher")
end)

test("bluetooth manager requests Bluetooth permission at startup", function()
    local hs = build_hs()
    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")

    bluetooth_sleep_manager.start()

    local probes = 0
    local with_user_env = nil
    for _, call in ipairs(hs.calls) do
        if call.type == "execute" and call.command == "/opt/homebrew/bin/blueutil --paired" then
            probes = probes + 1
            with_user_env = call.with_user_env
        end
    end

    assert_equal(probes, 1, "start should probe Bluetooth permission once")
    assert_false(with_user_env, "blueutil permission probe should not use user shell env")
end)

test("bluetooth utility resolves blueutil from the Intel Homebrew prefix", function()
    local hs = build_hs()
    hs.fs.files = { ["/usr/local/bin/blueutil"] = true }

    local bluetooth = load_module("utils.bluetooth")
    bluetooth.request_permission()

    local intel_probes = count_calls(hs, function(call)
        return call.type == "execute" and call.command == "/usr/local/bin/blueutil --paired"
    end)

    assert_equal(intel_probes, 1, "Intel Homebrew path should be used when Apple Silicon path is missing")
end)

test("bluetooth utility fails gracefully when blueutil is missing", function()
    local hs = build_hs()
    hs.fs.files = {}

    local bluetooth = load_module("utils.bluetooth")

    local connect_result = nil
    assert_false(bluetooth.request_permission(), "permission probe should fail without blueutil")
    assert_equal(#bluetooth.connected_devices(), 0, "device listing should be empty without blueutil")
    assert_false(bluetooth.connect("aa-bb-cc-dd-ee-ff", function(ok) connect_result = ok end),
        "connect should not start without blueutil")
    assert_false(connect_result, "connect callback should report failure")

    local shell_calls = count_calls(hs, function(call)
        return call.type == "execute" or call.type == "task"
    end)
    assert_equal(shell_calls, 0, "missing blueutil should never shell out")
end)

test("bluetooth utility validates addresses and ignores failed blueutil output", function()
    local hs = build_hs()
    local bluetooth = load_module("utils.bluetooth")

    local connect_result = nil
    assert_false(bluetooth.connect("not valid; rm -rf ~", function(ok) connect_result = ok end),
        "invalid addresses should be rejected")
    assert_false(connect_result, "connect callback should report failure for invalid addresses")
    assert_false(bluetooth.disconnect("not valid; rm -rf ~"), "invalid addresses should be rejected")

    hs.execute = function(command)
        table.insert(hs.calls, { type = "execute", command = command })
        return "bad", false, "exit", 1
    end

    assert_equal(#bluetooth.connected_devices(), 0, "failed blueutil should return no devices")

    local shell_calls = count_calls(hs, function(call)
        return call.type == "execute" or call.type == "task"
    end)
    assert_equal(shell_calls, 1, "invalid addresses should not execute shell commands")
end)

test("caffeinate at home enables only on home wifi and AC power", function()
    local hs = build_hs()
    hs.battery.source = "AC Power"
    hs.wifi.current = "Shadow"
    local caffeinate_at_home = load_module("modules.caffeinate_at_home")

    caffeinate_at_home.start({ "Shadow" })

    hs.battery.source = "Battery Power"
    hs.battery.callback()

    local enabled = 0
    local disabled = 0
    local ac_arg_seen = false
    for _, call in ipairs(hs.calls) do
        if call.type == "caffeinate_set" then
            if call.value then enabled = enabled + 1 else disabled = disabled + 1 end
            if call.ac_and_battery ~= nil then ac_arg_seen = true end
        end
    end

    assert_equal(enabled, 2, "AC home wifi should prevent system and display idle")
    assert_equal(disabled, 2, "battery should allow system and display idle")
    assert_false(ac_arg_seen, "systemIdle/displayIdle should not pass acAndBattery")
end)

test("caffeinate at home requests location before checking wifi", function()
    local hs = build_hs()
    hs.battery.source = "AC Power"
    hs.location.status = "undefined"
    hs.wifi.current = nil
    local caffeinate_at_home = load_module("modules.caffeinate_at_home")

    caffeinate_at_home.start({ "Shadow" })
    hs.timers[1]:fire()

    local location_get_index = nil
    local wifi_lookup_index = nil
    local disabled = 0
    for index, call in ipairs(hs.calls) do
        if call.type == "location_get" and not location_get_index then location_get_index = index end
        if call.type == "wifi_current_network" and not wifi_lookup_index then wifi_lookup_index = index end
        if call.type == "caffeinate_set" and not call.value then disabled = disabled + 1 end
    end

    assert_truthy(location_get_index, "start should activate Location Services")
    assert_truthy(wifi_lookup_index, "start should check the current WiFi network")
    assert_truthy(location_get_index < wifi_lookup_index, "Location Services should be requested before WiFi lookup")
    assert_equal(disabled, 2, "unavailable SSID should allow system and display idle")
end)

test("caffeinate at home debounces transient nil SSIDs", function()
    local hs = build_hs()
    hs.battery.source = "AC Power"
    hs.wifi.current = "Shadow"
    local caffeinate_at_home = load_module("modules.caffeinate_at_home")

    caffeinate_at_home.start({ "Shadow" })

    hs.wifi.current = nil
    hs.wifi.callback()

    local disabled_after_blip = count_calls(hs, function(call)
        return call.type == "caffeinate_set" and not call.value
    end)
    assert_equal(disabled_after_blip, 0, "transient nil SSID should not immediately allow sleep")

    hs.wifi.current = "Shadow"
    hs.wifi.callback()
    hs.timers[1]:fire()

    local disabled = count_calls(hs, function(call)
        return call.type == "caffeinate_set" and not call.value
    end)
    assert_equal(disabled, 0, "SSID returning during the settle window should keep caffeinate on")
end)

test("caffeinate at home applies a nil SSID that persists past the settle window", function()
    local hs = build_hs()
    hs.battery.source = "AC Power"
    hs.wifi.current = "Shadow"
    local caffeinate_at_home = load_module("modules.caffeinate_at_home")

    caffeinate_at_home.start({ "Shadow" })

    hs.wifi.current = nil
    hs.wifi.callback()
    hs.timers[1]:fire()

    local disabled = count_calls(hs, function(call)
        return call.type == "caffeinate_set" and not call.value
    end)
    assert_equal(disabled, 2, "a persistent nil SSID should allow system and display idle")
end)

test("caffeinate at home re-evaluates on system wake", function()
    local hs = build_hs()
    hs.battery.source = "AC Power"
    hs.wifi.current = "Shadow"
    local caffeinate_at_home = load_module("modules.caffeinate_at_home")

    caffeinate_at_home.start({ "Shadow" })

    hs.battery.source = "Battery Power"
    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)

    local disabled = count_calls(hs, function(call)
        return call.type == "caffeinate_set" and not call.value
    end)
    assert_equal(disabled, 2, "wake should re-evaluate the caffeinate state")
end)

test("caffeinate at home restarts with new SSIDs and validates input", function()
    local hs = build_hs()
    hs.battery.source = "AC Power"
    hs.wifi.current = "Shadow"
    local caffeinate_at_home = load_module("modules.caffeinate_at_home")

    assert_false(caffeinate_at_home.start(nil), "nil SSIDs should be rejected")
    assert_false(caffeinate_at_home.start({}), "empty SSIDs should be rejected")

    caffeinate_at_home.start({ "Shadow" })
    caffeinate_at_home.start({ "Other" })

    assert_equal(hs.wifi.watch_count, 2, "second start should replace the wifi watcher")
    assert_equal(hs.battery.watch_count, 2, "second start should replace the battery watcher")

    local last_set = nil
    for _, call in ipairs(hs.calls) do
        if call.type == "caffeinate_set" then last_set = call.value end
    end
    assert_false(last_set, "restart with non-matching SSIDs should allow sleep")

    caffeinate_at_home.stop()

    local final_set = nil
    for _, call in ipairs(hs.calls) do
        if call.type == "caffeinate_set" then final_set = call.value end
    end
    assert_false(final_set, "stop should allow sleep")
end)

test("bindings only keeps Hammerspoon hotkeys", function()
    local hs = build_hs()
    local bindings = load_module("bindings")

    bindings.bind()

    assert_equal(#hs.calls, 2, "only logger and reload hotkey should be registered")
    assert_equal(hs.calls[2].type, "hotkey")
    assert_equal(hs.calls[2].key, "f12")
    assert_false(read_file("tools/hammerspoon/config/.hammerspoon/bindings.lua"):find("yabai"),
        "bindings should not reference yabai")
end)

local failures = 0
for _, entry in ipairs(tests) do
    local ok, err = pcall(entry.fn)
    if ok then
        print("ok - " .. entry.name)
    else
        failures = failures + 1
        io.stderr:write("not ok - " .. entry.name .. "\n" .. err .. "\n")
    end
end

if failures > 0 then
    os.exit(1)
end
