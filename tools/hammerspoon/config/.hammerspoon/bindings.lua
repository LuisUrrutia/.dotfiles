local mod = {}

local log = hs.logger.new("bindings", "debug")

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

-- Remaining Hammerspoon-specific bindings
local hyper_key = {"cmd", "alt", "ctrl", "shift"}

local hyper_bindings = {
    { key = 'f12', fn = function()
        hs.reload()
    end },
    { key = 'f1', fn = reorg_spaces },
}

local function bind(key, opts)
    if opts.fn then
        hs.hotkey.bind(key, opts.key, opts.fn)
    end
end

function mod.bind()
    for _, binding in ipairs(hyper_bindings) do
       bind(hyper_key, binding)
    end
end

return mod