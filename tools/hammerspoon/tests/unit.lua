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
        periodic_timers = {},
        hotkey = {},
        json = {},
        task = {},
        tasks = {},
        task_fail = {},
        fs = { files = { ["/opt/homebrew/bin/blueutil"] = true } },
        bluetooth_powered_on = true,
        lid_output = '"AppleClamshellState" = No',
    }

    function hs.logger.new(name, level)
        table.insert(hs.calls, { type = "logger", name = name, level = level })

        local function record_log(log_level, message)
            table.insert(hs.calls, { type = "log", level = log_level, message = message })
        end

        return {
            d = function(message) record_log("debug", message) end,
            i = function(message) record_log("info", message) end,
            w = function(message) record_log("warning", message) end,
            e = function(message) record_log("error", message) end,
        }
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
        if hs.battery.unavailable then return nil end
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
                    self.stopped = true
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

    function hs.timer.doEvery(interval, fn)
        local timer = {
            interval = interval,
            fire = function(self)
                if not self.stopped then fn() end
            end,
            stop = function(self) self.stopped = true end,
        }
        table.insert(hs.periodic_timers, timer)
        return timer
    end

    function hs.hotkey.bind(mods, key, fn)
        table.insert(hs.calls, { type = "hotkey", mods = mods, key = key, fn = fn })
    end

    function hs.execute(command, with_user_env)
        table.insert(hs.calls, { type = "execute", command = command, with_user_env = with_user_env })
        if command == "/usr/sbin/ioreg -r -n IOPMrootDomain -d 1 -l" then
            return hs.lid_output, not hs.lid_probe_failed
        end
        if hs.execute_failed then return "bad", false, "exit", 1 end
        if command:find(" %-p") then
            if hs.bluetooth_powered_on then
                return "1\n", true, "exit", 0
            end

            return "0\n", true, "exit", 0
        end

        return "", true, "exit", 0
    end

    function hs.task.new(path, callback, arguments)
        if hs.task.create_failed then return nil end
        local task = {
            finish = function(self, exit_code)
                self.running = false
                callback(exit_code, "", "")
            end,
            terminate = function(self)
                self.terminated = true
                self.running = false
                return self
            end,
            isRunning = function(self) return self.running == true end,
            start = function(self)
                table.insert(hs.calls, { type = "task", path = path, arguments = arguments })
                if hs.task.start_failed then return false end
                self.running = true
                local exit_code = hs.task_fail[arguments[#arguments]] and 1 or 0
                if not hs.task.deferred then
                    self:finish(exit_code)
                end
                return self
            end,
        }
        table.insert(hs.tasks, task)
        return task
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

local function close_lid(hs)
    hs.lid_output = '"AppleClamshellState" = Yes'
    hs.caffeinate.callback(hs.caffeinate.watcher.systemWillSleep)
end

local function open_lid(hs)
    hs.lid_output = '"AppleClamshellState" = No'
    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)
end

test("bluetooth manager leaves devices connected when sleeping with the lid open", function()
    local hs = build_hs()
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()

    hs.caffeinate.callback(hs.caffeinate.watcher.screensDidSleep)
    hs.caffeinate.callback(hs.caffeinate.watcher.systemWillSleep)
    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)

    assert_equal(count_disconnects(hs), 0, "sleep with an open lid must preserve Bluetooth connections")
    assert_equal(#hs.timers, 0, "ordinary wake must not schedule Bluetooth connections")
end)

test("bluetooth manager follows the lid while the Mac stays awake", function()
    local hs = build_hs()
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()

    hs.lid_output = '"AppleClamshellState" = Yes'
    hs.periodic_timers[1]:fire()
    hs.periodic_timers[1]:fire()
    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)

    assert_equal(count_disconnects(hs), 1, "a docked lid close must disconnect once without a sleep event")
    assert_equal(#hs.timers, 0, "wake with the lid still closed must not reconnect")

    hs.lid_output = '"AppleClamshellState" = No'
    hs.periodic_timers[1]:fire()
    hs.timers[1]:fire()
    hs.timers[2]:fire()

    assert_equal(count_connects(hs), 1, "opening the lid without a wake event must reconnect")
end)

test("bluetooth manager does not disconnect on reload with the lid already closed", function()
    local hs = build_hs()
    hs.lid_output = '"AppleClamshellState" = Yes'
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()

    hs.periodic_timers[1]:fire()
    hs.caffeinate.callback(hs.caffeinate.watcher.systemDidWake)

    assert_equal(count_disconnects(hs), 0, "reload must preserve active docked peripherals")
    assert_equal(#hs.timers, 0, "reload must not invent previously disconnected devices")

    open_lid(hs)
    close_lid(hs)
    assert_equal(count_disconnects(hs), 1, "the next lid close must still be observed")
end)

test("bluetooth manager ignores missing, malformed, or failed lid readings", function()
    local hs = build_hs()
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()

    for _, output in ipairs({ "", '"AppleClamshellState" = unknown' }) do
        hs.lid_output = output
        hs.periodic_timers[1]:fire()
    end
    hs.lid_probe_failed = true
    close_lid(hs)
    assert_equal(count_disconnects(hs), 0, "an unreadable lid must not disconnect devices")

    hs.lid_probe_failed = false
    close_lid(hs)
    hs.lid_output = ""
    hs.periodic_timers[1]:fire()
    assert_equal(#hs.timers, 0, "a missing lid state must not be mistaken for opening")

    open_lid(hs)
    hs.lid_probe_failed = true
    hs.timers[1]:fire()
    assert_equal(count_connects(hs), 0, "reconnect must wait until the lid is known to be open")
end)

test("bluetooth manager checks the lid again before a delayed reconnect", function()
    local hs = build_hs()
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()
    close_lid(hs)
    open_lid(hs)

    hs.lid_output = '"AppleClamshellState" = Yes'
    hs.timers[1]:fire()

    assert_equal(count_connects(hs), 0, "a delayed reconnect must not race the next lid check")
end)

test("bluetooth manager uses lid transitions, dedupes devices, and delays reconnect", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-ff" },
        { address = "aa-bb-cc-dd-ee-ff" },
    }

    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")
    bluetooth_sleep_manager.start()

    hs.caffeinate.callback(hs.caffeinate.watcher.screensDidSleep)
    close_lid(hs)
    open_lid(hs)
    hs.timers[1]:fire()
    hs.timers[2]:fire()

    assert_equal(count_disconnects(hs), 1, "lid closure should disconnect each device once")
    assert_equal(count_connects(hs), 1, "lid opening should reconnect each device once")
    assert_equal(#hs.timers, 2, "wake should schedule a delayed reconnect and a settle check")
end)

test("bluetooth manager retries when Bluetooth is off after opening", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-ff" },
    }

    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")
    bluetooth_sleep_manager.start()

    close_lid(hs)

    hs.bluetooth_powered_on = false
    open_lid(hs)
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

    close_lid(hs)

    hs.bluetooth_powered_on = false
    open_lid(hs)

    local index = 1
    while hs.timers[index] do
        hs.timers[index]:fire()
        index = index + 1
    end

    assert_equal(#hs.timers, 5, "retries should stop after the attempt limit")
    assert_equal(count_connects(hs), 0, "no reconnect should run while Bluetooth is off")

    open_lid(hs)
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

    close_lid(hs)
    open_lid(hs)

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
    assert_equal(#hs.periodic_timers, 1, "start should create one lid timer")
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

test("bluetooth manager cancels a pending reconnect on a new lid cycle", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-ff" },
    }

    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")
    bluetooth_sleep_manager.start()

    close_lid(hs)
    open_lid(hs)
    local stale_timer = hs.timers[1]

    close_lid(hs)
    assert_truthy(stale_timer.stopped, "a new lid cycle should cancel the pending reconnect")

    open_lid(hs)
    stale_timer:fire()
    assert_equal(count_connects(hs), 0, "a stale timer should not reconnect while the machine sleeps")

    hs.timers[2]:fire()
    assert_equal(count_connects(hs), 1, "the current wake cycle should reconnect the remembered device")
end)

test("bluetooth manager stop cancels a pending reconnect", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-ff" },
    }

    local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")
    bluetooth_sleep_manager.start()

    close_lid(hs)
    open_lid(hs)
    local pending_timer = hs.timers[1]

    bluetooth_sleep_manager.stop()
    assert_truthy(pending_timer.stopped, "stop should cancel the pending reconnect")
    assert_truthy(hs.periodic_timers[1].stopped, "stop should cancel the lid timer")

    pending_timer:fire()
    assert_equal(count_connects(hs), 0, "a stopped manager should not reconnect devices")
end)

test("bluetooth manager waits for an in-flight connection before retrying", function()
    local hs = build_hs()
    hs.task.deferred = true
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()
    close_lid(hs)
    open_lid(hs)

    for index = 1, 3 do hs.timers[index]:fire() end

    assert_equal(count_connects(hs), 1, "a slow connection must not spawn overlapping blueutil processes")
    hs.tasks[1]:finish(0)
    hs.timers[4]:fire()
    assert_equal(#hs.timers, 4, "a successful delayed connection should finish the retry loop")
end)

test("bluetooth manager bounds hung connections and cancels them before retrying", function()
    local hs = build_hs()
    hs.task.deferred = true
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()
    close_lid(hs)
    open_lid(hs)

    local index = 1
    while hs.timers[index] and index <= 40 do
        hs.timers[index]:fire()
        local running = 0
        for _, task in ipairs(hs.tasks) do
            if task:isRunning() then running = running + 1 end
        end
        assert_truthy(running <= 1, "a retry must terminate the previous process before starting another")
        index = index + 1
    end

    assert_false(hs.timers[index], "hung connections must have a bounded retry budget")
    assert_equal(count_connects(hs), 5, "each hung attempt should consume the retry budget once")
    for _, task in ipairs(hs.tasks) do
        assert_truthy(task.terminated, "a timed-out task must be terminated")
    end
end)

test("bluetooth manager cancels active tasks on lid close and ignores their late callbacks", function()
    local hs = build_hs()
    hs.task.deferred = true
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()
    close_lid(hs)
    open_lid(hs)
    hs.timers[1]:fire()
    local old_task = hs.tasks[1]

    close_lid(hs)
    old_task:finish(0)
    open_lid(hs)
    if hs.timers[3] then hs.timers[3]:fire() end

    assert_equal(count_connects(hs), 2, "a stale completion must not erase the next lid cycle's devices")
    assert_truthy(old_task.terminated, "lid closure must cancel the previous connection process")
end)

test("bluetooth manager cancels active tasks on stop", function()
    local hs = build_hs()
    hs.task.deferred = true
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()
    close_lid(hs)
    open_lid(hs)
    hs.timers[1]:fire()

    manager.stop()

    assert_truthy(hs.tasks[1].terminated, "stop must terminate the active connection process")
    assert_truthy(hs.timers[2].stopped, "stop must cancel the connection check")
end)

test("bluetooth manager snapshots connected devices even when earlier devices still need retrying", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-01" },
        { address = "aa-bb-cc-dd-ee-02" },
    }
    hs.task_fail["aa-bb-cc-dd-ee-02"] = true
    local manager = load_module("modules.bluetooth_sleep_manager")
    manager.start()
    close_lid(hs)
    open_lid(hs)
    hs.timers[1]:fire()
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-01" } }

    close_lid(hs)
    open_lid(hs)
    hs.timers[3]:fire()

    assert_equal(count_disconnects(hs), 3, "a partially successful wake must not skip the next lid closure snapshot")
    assert_equal(count_connects(hs, "aa-bb-cc-dd-ee-01"), 2, "each lid closure must remember the connected device")
    assert_equal(count_connects(hs, "aa-bb-cc-dd-ee-02"), 2, "the still-disconnected device must remain remembered")
end)

for _, failure in ipairs({ "create_failed", "start_failed" }) do
    test("bluetooth utility reports task " .. failure .. " exactly once", function()
        local hs = build_hs()
        hs.task[failure] = true
        local bluetooth = load_module("utils.bluetooth")
        local results = {}

        local started = bluetooth.connect("aa-bb-cc-dd-ee-ff", function(ok)
            table.insert(results, ok)
        end)

        assert_false(started, "a failed task must not count as started")
        assert_equal(#results, 1, "failure must complete the connection callback")
        assert_equal(results[1], false, "callback must report failure")
    end)
end

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

    hs.execute_failed = true
    hs.json.next_value = { { address = "aa-bb-cc-dd-ee-ff" } }

    assert_equal(#bluetooth.connected_devices(), 0, "failed blueutil should return no devices")

    local shell_calls = count_calls(hs, function(call)
        return call.type == "execute" or call.type == "task"
    end)
    assert_equal(shell_calls, 1, "invalid addresses should not execute shell commands")
end)

test("bluetooth utility filters malformed connected-device records", function()
    local hs = build_hs()
    hs.json.next_value = {
        { address = "aa-bb-cc-dd-ee-ff", name = "Headphones" },
        { address = "invalid" },
        {},
        "not a device",
    }
    local bluetooth = load_module("utils.bluetooth")

    local devices = bluetooth.connected_devices()

    assert_equal(#devices, 1, "only records with valid Bluetooth addresses should be returned")
    assert_equal(devices[1].address, "aa-bb-cc-dd-ee-ff")
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

test("caffeinate at home ignores transient startup authorization status", function()
    local hs = build_hs()
    hs.location.status = "undefined"
    hs.wifi.current = "Shadow"
    local caffeinate_at_home = load_module("modules.caffeinate_at_home")

    caffeinate_at_home.start({ "Shadow" })

    local location_warnings = 0
    for _, call in ipairs(hs.calls) do
        local is_location_warning = call.type == "log"
            and call.level == "warning"
            and call.message:find("Location Services status", 1, true)
        if is_location_warning then
            location_warnings = location_warnings + 1
        end
    end

    assert_equal(location_warnings, 0, "transient startup authorization should not emit a warning")
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

test("caffeinate at home releases sleep prevention immediately on battery without an SSID", function()
    local hs = build_hs()
    hs.battery.source = "AC Power"
    hs.wifi.current = "Shadow"
    local caffeinate = load_module("modules.caffeinate_at_home")
    caffeinate.start({ "Shadow" })
    hs.wifi.current = nil
    hs.wifi.callback()

    hs.battery.source = "Battery Power"
    hs.battery.callback()

    assert_equal(count_calls(hs, function(call)
        return call.type == "caffeinate_set" and not call.value
    end), 2, "battery power must release both assertions without waiting for WiFi")
    assert_truthy(hs.timers[1].stopped, "battery power should cancel the WiFi settle timer")
end)

test("caffeinate at home bounds the nil SSID grace period across repeated notifications", function()
    local hs = build_hs()
    hs.battery.source = "AC Power"
    hs.wifi.current = "Shadow"
    local caffeinate = load_module("modules.caffeinate_at_home")
    caffeinate.start({ "Shadow" })
    hs.wifi.current = nil
    hs.wifi.callback()

    hs.wifi.callback()
    hs.battery.callback()
    hs.timers[1]:fire()

    assert_equal(count_calls(hs, function(call)
        return call.type == "caffeinate_set" and not call.value
    end), 2, "repeated notifications must not keep extending sleep prevention")
    assert_equal(#hs.timers, 1, "one missing-SSID episode should use one grace period")
end)

test("caffeinate at home allows sleep when the power source is unavailable", function()
    local hs = build_hs()
    hs.battery.source = "AC Power"
    hs.wifi.current = "Shadow"
    local caffeinate = load_module("modules.caffeinate_at_home")
    caffeinate.start({ "Shadow" })

    hs.battery.unavailable = true
    hs.battery.callback()

    assert_equal(count_calls(hs, function(call)
        return call.type == "caffeinate_set" and not call.value
    end), 2, "an unavailable power source must allow sleep without throwing")
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

test("Hammerspoon shutdown stops every managed module", function()
    local hs = build_hs()
    unload_modules()

    local bluetooth_stops = 0
    local caffeinate_stops = 0
    package.loaded["modules.bluetooth_sleep_manager"] = {
        start = function() end,
        stop = function() bluetooth_stops = bluetooth_stops + 1 end,
    }
    package.loaded["modules.caffeinate_at_home"] = {
        start = function() end,
        stop = function() caffeinate_stops = caffeinate_stops + 1 end,
    }
    package.loaded.bindings = { bind = function() end }

    dofile(root .. "/tools/hammerspoon/config/.hammerspoon/init.lua")
    hs.shutdownCallback()

    assert_equal(bluetooth_stops, 1, "shutdown should stop the Bluetooth manager")
    assert_equal(caffeinate_stops, 1, "shutdown should stop the caffeinate manager")
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
