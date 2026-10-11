return {
  {
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp" },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      vim.lsp.config("*", {
        capabilities = capabilities,
      })

      vim.lsp.config("astro", {
        before_init = function(_, config)
          local tsdk = require("lspconfig.util").get_typescript_server_path(config.root_dir)
          if tsdk == "" then
            local installed = vim.system({ "mise", "where", "npm:typescript@6" }, { text = true }):wait()
            if installed.code ~= 0 then
              error("Astro needs the mise-managed TypeScript 6 SDK: " .. installed.stderr)
            end
            local root = vim.trim(installed.stdout)
            for _, directory in ipairs({ "/node_modules/typescript/lib", "/lib/node_modules/typescript/lib" }) do
              if vim.uv.fs_stat(root .. directory .. "/tsserverlibrary.js") then
                tsdk = root .. directory
                break
              end
            end
            assert(tsdk ~= "", "The mise-managed TypeScript 6 SDK is missing")
          end
          config.init_options.typescript.tsdk = tsdk
        end,
      })
      vim.lsp.enable({ "rust_analyzer", "lua_ls", "tailwindcss", "astro", "docker_language_server", "vtsls" })
    end,
  },
  {
    "saghen/blink.cmp",
    event = "InsertEnter",
    dependencies = {
      "saghen/blink.lib",
      "L3MON4D3/LuaSnip",
    },
    build = function()
      if not require("config.blink").ensure() then
        error("blink.cmp native library build failed")
      end
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
