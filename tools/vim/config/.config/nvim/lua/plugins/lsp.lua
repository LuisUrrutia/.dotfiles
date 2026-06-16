return {
    { "neovim/nvim-lspconfig" },
    { "mason-org/mason.nvim", opts = {} },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            automatic_enable = true,
            ensure_installed = {
                "rust_analyzer",
                "lua_ls",
                "tailwindcss",
                "astro",
                "docker_language_server",
                "vtsls"
            }
        },
        dependencies = {
            "mason-org/mason.nvim",
            "neovim/nvim-lspconfig",
            "saghen/blink.cmp",
        },
        config = function(_, opts)
            local capabilities = require("blink.cmp").get_lsp_capabilities()

            vim.lsp.config("*", {
                capabilities = capabilities,
            })

            require("mason-lspconfig").setup(opts)
        end,
    },
    {
        "saghen/blink.cmp",
        event = "InsertEnter",
        dependencies = {
            "saghen/blink.lib",
            "neovim/nvim-lspconfig",
            "L3MON4D3/LuaSnip",
        },
        build = function()
            require("blink.cmp").build():pwait()
        end,
        opts = {
            keymap = {
                preset = "default",
                ["<C-n>"] = { "select_next", "fallback" },
                ["<C-p>"] = { "select_prev", "fallback" },
                ["<C-d>"] = { "scroll_documentation_up", "fallback" },
                ["<C-f>"] = { "scroll_documentation_down", "fallback" },
                ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
                ["<C-e>"] = { "hide", "fallback" },
                ["<CR>"] = { "accept", "fallback" },
            },
            snippets = {
                preset = "luasnip",
            },
            sources = {
                default = { "lsp", "buffer", "path", "snippets" },
            },
            completion = {
                documentation = {
                    auto_show = true,
                },
            },
            cmdline = {
                enabled = true,
            },
        },
    },
}
