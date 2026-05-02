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
        build = function(plugin)
            local lib = require("blink.lib").native
            local platform = lib.platform()
            local commit_result = vim.system({ "git", "rev-parse", "HEAD" }, { cwd = plugin.dir }):wait()

            if commit_result.code ~= 0 then
                error(commit_result.stderr)
            end

            local build_result = vim.system({ "cargo", "build", "--release" }, { cwd = plugin.dir }):wait()

            if build_result.code ~= 0 then
                error(build_result.stderr)
            end

            local commit = vim.trim(commit_result.stdout)
            local source = plugin.dir .. "/target/release/libblink_cmp_fuzzy" .. platform.lib_extension
            local destination = lib.library_path("blink_cmp_fuzzy", commit)
            local fallback_destination = lib.library_path("blink_cmp_fuzzy")

            lib.mkdirp(vim.fs.dirname(fallback_destination))

            if vim.uv.fs_stat(fallback_destination) then
                vim.uv.fs_unlink(fallback_destination)
            end

            local copied, copy_error = vim.uv.fs_copyfile(source, fallback_destination)

            if not copied then
                error(copy_error)
            end

            lib.mv(source, destination)
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
