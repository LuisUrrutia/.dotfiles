local mod = {}

local log = hs.logger.new("bindings", "debug")

local app_space_mapping = {
    ["kitty"] = "terminal",
    ["Cursor"] = "code",
    ["Brave Browser"] = "web",
    ["Telegram"] = "social",
    ["WhatsApp"] = "social",
    ["Discord"] = "social",
    ["Fantastical"] = "work",
    ["Slack"] = "work",
    ["Zoom"] = "work",
    ["Music"] = "other",
    ["Spotify"] = "other",
}

local function yabai(commands)
    for _, cmd in ipairs(commands) do
        os.execute("/opt/homebrew/bin/yabai -m " .. cmd)
    end
end

local function reorg_spaces()
    log.d("Reorganizing spaces")
    local yabai_commands = {}

    local output, status = hs.execute("yabai -m query --displays | jq '. | length'", true)
    if status == true then
        if (tonumber(output) or 0) > 1 then
            log.d("Moving spaces to second display")
            table.insert(yabai_commands, "space work --display 2")

            table.insert(yabai_commands, "space social --display 2")
            table.insert(yabai_commands, "space other --display 2")
        end
    end

    -- Reorganize windows based on rules
    table.insert(yabai_commands, "rule --apply")

    yabai(yabai_commands)
end

local hyper_key = {"cmd", "alt", "ctrl", "shift"}

local hyper_bindings = {
    { key = 't', bundle_id = 'net.kovidgoyal.kitty' },
    { key = 'b', bundle_id = 'com.brave.Browser' },
    { key = 'c', app = 'Cursor' },
    { key = 'f12', fn = function()
        hs.reload()
    end },
    { key = 'f1', fn = reorg_spaces },

}
local cmd_bindings = {
    { key = '`', bundle_id = 'net.kovidgoyal.kitty' },
}

local alt_bindings = {
    { key = 'f', yabai = { "window --toggle zoom-fullscreen" } },
    { key = 'r', yabai = { "window --toggle rotate 90" } },
    { key = '`', yabai = { "space --balance" } },
    { key = 'h', yabai = { "window --focus west" } },
    { key = 'j', yabai = { "window --focus north" } },
    { key = 'k', yabai = { "window --focus south" } },
    { key = 'l', yabai = { "window --focus east" } },


    { key = 't', yabai = { "space --focus terminal" } },
    { key = 'c', yabai = { "space --focus code" } },
    { key = 'b', yabai = { "space --focus web" } },
    { key = 'w', yabai = { "space --focus work" } },
    { key = 'o', yabai = { "space --focus other" } },
    { key = 's', yabai = { "space --focus social" } },
    { key = 'left', yabai = { "window --focus stack.prev" } },
    { key = 'right', yabai = { "window --focus stack.next" } },
}

-- Add alt+1-7 bindings to focus space
for i = 1, 7 do
    table.insert(alt_bindings, { key = tostring(i), yabai = { "space --focus " .. i } })
end

local alt_shift_bindings = {
    { key = '[', yabai = { "space --display 1" }},
    { key = ']', yabai = { "space --display 2" }}
}

-- Add alt+shift+1-7 bindings to move window to space
for i = 1, 7 do
    table.insert(alt_shift_bindings, { key = tostring(i), yabai = { "window --space " .. i, "space --focus " .. i } })
end


local function bind(key, opts)
    if opts.bundle_id then
        hs.hotkey.bind(key, opts.key, function()
            hs.application.launchOrFocusByBundleID(opts.bundle_id)
        end)
    elseif opts.app then
        hs.hotkey.bind(key, opts.key, function()
            hs.application.launchOrFocus(opts.app)
        end)
    elseif opts.fn then
        hs.hotkey.bind(key, opts.key, opts.fn)
    elseif opts.yabai then
        hs.hotkey.bind(key, opts.key, function()
            yabai(opts.yabai)
        end)
    end
end

function mod.bind()
    for _, binding in ipairs(hyper_bindings) do
       bind(hyper_key, binding)
    end
    for _, binding in ipairs(cmd_bindings) do
        bind({ "cmd " }, binding)
    end
    for _, binding in ipairs(alt_bindings) do
        bind({ "alt" }, binding)
    end
    for _, binding in ipairs(alt_shift_bindings) do
        bind({ "alt", "shift" }, binding)
    end
end

return mod