local root = os.getenv("DOTFILES_TEST_ROOT") or (os.getenv("PWD") or ".")
package.path = root .. "/tools/hammerspoon/config/.hammerspoon/?.lua;" .. root .. "/tools/hammerspoon/config/.hammerspoon/?/init.lua;" .. package.path

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
    timer = {},
    hotkey = {},
    json = {},
  }

  function hs.logger.new(name, level)
    table.insert(hs.calls, { type = "logger", name = name, level = level })
    return { d = function() end, i = function() end, w = function() end, e = function() end }
  end

  function hs.caffeinate.set(kind, value, ac_and_battery)
    table.insert(hs.calls, { type = "caffeinate_set", kind = kind, value = value, ac_and_battery = ac_and_battery })
  end

  function hs.caffeinate.get(kind)
    return hs.caffeinate.values and hs.caffeinate.values[kind] or false
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

  function hs.wifi.currentNetwork()
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
    table.insert(hs.calls, { type = "timer", delay = delay })
    fn()
    return { stop = function() end }
  end

  function hs.hotkey.bind(mods, key, fn)
    table.insert(hs.calls, { type = "hotkey", mods = mods, key = key, fn = fn })
  end

  function hs.execute(command)
    table.insert(hs.calls, { type = "execute", command = command })
    if command:find(" %-p") then
      return "1\n", true, "exit", 0
    end

    return "", true, "exit", 0
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

  local disconnects = 0
  local connects = 0
  local timers = 0
  for _, call in ipairs(hs.calls) do
    if call.type == "execute" and call.command:find("%-%-disconnect") then disconnects = disconnects + 1 end
    if call.type == "execute" and call.command:find("%s%-%-connect%s") then connects = connects + 1 end
    if call.type == "timer" then timers = timers + 1 end
  end

  assert_equal(disconnects, 1, "system sleep should disconnect each device once")
  assert_equal(connects, 1, "system wake should reconnect each device once")
  assert_equal(timers, 1, "wake reconnect should be delayed")
end)

test("bluetooth manager start is idempotent", function()
  local hs = build_hs()
  local bluetooth_sleep_manager = load_module("modules.bluetooth_sleep_manager")

  bluetooth_sleep_manager.start()
  bluetooth_sleep_manager.start()

  assert_equal(hs.caffeinate.watch_count, 1, "start should create one watcher")
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

test("caffeinate at home validates SSIDs and restores secure defaults on stop", function()
  local hs = build_hs()
  hs.battery.source = "AC Power"
  hs.wifi.current = "Shadow"
  local caffeinate_at_home = load_module("modules.caffeinate_at_home")

  assert_false(caffeinate_at_home.start(nil), "nil SSIDs should be rejected")
  caffeinate_at_home.start({ "Shadow" })
  caffeinate_at_home.start({ "Shadow" })
  caffeinate_at_home.stop()

  assert_equal(hs.wifi.watch_count, 1, "start should create one wifi watcher")
  assert_equal(hs.battery.watch_count, 1, "start should create one battery watcher")

  local password_enabled = 0
  for _, call in ipairs(hs.calls) do
    if call.type == "execute" and call.command:find("askForPassword %-int 1") then
      password_enabled = password_enabled + 1
    end
  end
  assert_truthy(password_enabled > 0, "stop should require screensaver password")
end)

test("screensaver avoids duplicate writes and sets password delay", function()
  local hs = build_hs()
  local screensaver = load_module("utils.screensaver")

  screensaver.set_require_password(true)
  screensaver.set_require_password(true)
  screensaver.set_require_password(false)

  local ask_password_writes = 0
  local delay_writes = 0
  for _, call in ipairs(hs.calls) do
    if call.type == "execute" and call.command:find("askForPassword %-int") then ask_password_writes = ask_password_writes + 1 end
    if call.type == "execute" and call.command:find("askForPasswordDelay") then delay_writes = delay_writes + 1 end
  end

  assert_equal(ask_password_writes, 2, "duplicate password states should not be rewritten")
  assert_equal(delay_writes, 2, "password delay should be managed with password state")
end)

test("bluetooth utility validates addresses and ignores failed blueutil output", function()
  local hs = build_hs()
  local bluetooth = load_module("utils.bluetooth")

  hs.execute = function(command)
    table.insert(hs.calls, { type = "execute", command = command })
    return "bad", false, "exit", 1
  end

  assert_false(bluetooth.connect("not valid; rm -rf ~"), "invalid addresses should be rejected")
  assert_equal(#bluetooth.connected_devices(), 0, "failed blueutil should return no devices")
  assert_equal(#hs.calls, 1, "invalid address should not execute shell command")
end)

test("bindings only keeps Hammerspoon hotkeys", function()
  local hs = build_hs()
  local bindings = load_module("bindings")

  bindings.bind()

  assert_equal(#hs.calls, 2, "only logger and reload hotkey should be registered")
  assert_equal(hs.calls[2].type, "hotkey")
  assert_equal(hs.calls[2].key, "f12")
  assert_false(read_file("tools/hammerspoon/config/.hammerspoon/bindings.lua"):find("yabai"), "bindings should not reference yabai")
end)

test("hammerspoon install and brewfiles include runtime dependencies", function()
  local install = read_file("tools/hammerspoon/install.sh")
  local core = read_file("brewfiles/core")
  local personal = read_file("brewfiles/personal")

  assert_truthy(install:find("require_brew_bin blueutil", 1, true), "install should check blueutil")
  assert_truthy(core:find('brew "jq"', 1, true), "core Brewfile should install jq")
  assert_false(install:find("require_brew_bin jq", 1, true), "install should not require unused jq")
  assert_false(install:find("yabai", 1, true), "install should not require yabai")
  assert_truthy(personal:find("yabai", 1, true), "personal Brewfile can still install yabai for other tools")
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
