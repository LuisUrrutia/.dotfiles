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
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        opts = {
            theme = "catppuccin-mocha"
        }
    },
    {
        'nvimdev/dashboard-nvim',
        event = 'VimEnter',
        config = {
            hide = {
                statusline = false
            },
            config = {
                shortcut = {},
                footer = {}
            }
        },
        dependencies = { { 'nvim-tree/nvim-web-devicons' } }
    }
}
