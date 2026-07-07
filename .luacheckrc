-- Hammerspoon embeds Lua 5.4
std = "lua54"

-- Hammerspoon injects its API as a global; config code may assign
-- the documented callback/settings fields
read_globals = {
    hs = {
        other_fields = true,
        fields = {
            shutdownCallback = { read_only = false },
            logger = {
                other_fields = true,
                fields = {
                    defaultLogLevel = { read_only = false },
                },
            },
        },
    },
}

files["tools/hammerspoon/tests/unit.lua"] = {
    -- The test harness builds and installs its own hs mock
    globals = { "hs" },
    -- Mock functions mirror real signatures and may ignore arguments
    unused_args = false,
}
