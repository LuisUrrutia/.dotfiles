return {
    {
        "NickvanDyke/opencode.nvim",
        version = "*",
        dependencies = {
            "folke/snacks.nvim",
        },
        keys = {
            {
                "<leader>ot",
                function()
                    require("opencode").toggle()
                end,
                desc = "Toggle OpenCode",
            },
            {
                "<leader>oa",
                function()
                    require("opencode").ask("@this: ")
                end,
                desc = "Ask OpenCode about this",
            },
            {
                "<leader>oa",
                function()
                    require("opencode").ask("@this: ")
                end,
                mode = "v",
                desc = "Ask OpenCode about this",
            },
            {
                "<leader>o+",
                function()
                    require("opencode").prompt("@buffer", { append = true })
                end,
                desc = "Add buffer to OpenCode prompt",
            },
            {
                "<leader>o+",
                function()
                    require("opencode").prompt("@this", { append = true })
                end,
                mode = "v",
                desc = "Add selection/range to OpenCode prompt",
            },
            {
                "<leader>oe",
                function()
                    require("opencode").prompt("Explain @this and its context")
                end,
                desc = "Explain this with OpenCode",
            },
            {
                "<leader>on",
                function()
                    require("opencode").command("session.new")
                end,
                desc = "New OpenCode session",
            },
            {
                "<leader>os",
                function()
                    require("opencode").select()
                end,
                mode = { "n", "v" },
                desc = "Select OpenCode prompt",
            },
        },
        config = function()
            vim.g.opencode_opts = {}
            vim.opt.autoread = true
        end,
    },
}
