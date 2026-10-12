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

files["conf.d/nvim/**/*.lua"] = {
    std = "luajit",
    globals = { "vim" },
}
