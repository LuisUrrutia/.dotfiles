return {
    {
        'stevearc/conform.nvim',
        opts = {
            formatters_by_ft = {
                lua = { "stylua" },
                go = { "goimports", "gofmt" },
                rust = { "rustfmt", lsp_format = "fallback" },
                javascript = { "prettier" },
                typescript = { "prettier" },
                astro = { "prettier" },
                markdown = { "markdownlint-cli2" },
                yaml = { "yamlfmt" },
                fish = { "fish_indent" },
                sh = { "shfmt" },
                python = function(bufnr)
                    if require("conform").get_formatter_info("ruff_format", bufnr).available then
                        return { "ruff_format" }
                    else
                        return { "isort", "black" }
                    end
                end,
            },
            default_format_opts = {
                lsp_format = "fallback"
            },
            format_on_save = {
                timeout_ms = 1000,
                lsp_format = "fallback"
            },
            notify_on_error = true,
            notify_no_formatters = true,
        },
    }
}
