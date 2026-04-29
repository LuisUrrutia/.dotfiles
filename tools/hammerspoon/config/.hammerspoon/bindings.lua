local mod = {}

local log = hs.logger.new("bindings")

-- Remaining Hammerspoon-specific bindings
local hyper_key = {"cmd", "alt", "ctrl", "shift"}

local hyper_bindings = {
    { key = 'f12', fn = function()
        log.i("Reloading Hammerspoon")
        hs.reload()
    end },
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
