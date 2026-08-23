return {
  {
    "stevearc/conform.nvim",
    cmd = "ConformInfo",
    event = { "BufWritePre" },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        go = { "gofmt" },
        rust = { "rustfmt", lsp_format = "fallback" },
        javascript = { "biome" },
        typescript = { "biome" },
        markdown = { "markdownlint-cli2" },
        yaml = { "yamlfmt" },
        fish = { "fish_indent" },
        sh = { "shfmt" },
      },
      default_format_opts = {
        lsp_format = "fallback",
      },
      format_on_save = {
        timeout_ms = 1000,
        lsp_format = "fallback",
      },
      notify_on_error = true,
      notify_no_formatters = true,
    },
  },
}
