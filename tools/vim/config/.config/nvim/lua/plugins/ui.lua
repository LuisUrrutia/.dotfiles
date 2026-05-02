return {
    {
        'catppuccin/nvim',
        name = "catppuccin",
        lazy = false,    -- make sure we load this during startup if it is your main colorscheme
        priority = 1000, -- make sure to load this before all the other start plugins
        config = function()
            vim.cmd([[colorscheme catppuccin-mocha]])
        end
    },
    {
        'nvim-lualine/lualine.nvim',
        event = 'VeryLazy',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        opts = {
            theme = "catppuccin-mocha"
        }
    },
    {
        'folke/snacks.nvim',
        lazy = false,
        priority = 1000,
        opts = {
            dashboard = { enabled = true },
            input = { enabled = true },
        },
    }
}
