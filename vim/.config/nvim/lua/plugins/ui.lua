return {{
    'catppuccin/nvim',
    name = "catppuccin",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
        vim.cmd([[colorscheme catppuccin-mocha]])
    end
}, {
    'nvim-lualine/lualine.nvim',
    dependencies = {'nvim-tree/nvim-web-devicons'},
    opts = function()
        local lualine_require = require("lualine_require")
        lualine_require.require = require

        return {
            options = {
                theme = "catppuccin-mocha"
            }
        }
    end
}}
