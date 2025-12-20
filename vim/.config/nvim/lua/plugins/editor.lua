return {
    {
        -- `gc` and `gb` to comment/uncomment
        'numToStr/Comment.nvim',
        opts = {}
    },
    {
        'echasnovski/mini.surround',
        version = '*'
    },
    {
        "folke/trouble.nvim",
        opts = {
            use_diagnostic_signs = true
        },
        cmd = "Trouble",
        keys = {
            {
                "<leader>xx",
                "<cmd>Trouble diagnostics toggle<cr>",
                desc = "Diagnostics (Trouble)",
            },
            {
                "<leader>xX",
                "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
                desc = "Buffer Diagnostics (Trouble)",
            },
            {
                "<leader>cs",
                "<cmd>Trouble symbols toggle focus=false<cr>",
                desc = "Symbols (Trouble)",
            },
            {
                "<leader>cl",
                "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
                desc = "LSP Definitions / references / ... (Trouble)",
            },
            {
                "<leader>xL",
                "<cmd>Trouble loclist toggle<cr>",
                desc = "Location List (Trouble)",
            },
            {
                "<leader>xQ",
                "<cmd>Trouble qflist toggle<cr>",
                desc = "Quickfix List (Trouble)",
            },
        },
    },
    {
        'lewis6991/gitsigns.nvim',
        lazy = false,
        opts = {
            current_line_blame = true,
            current_line_blame_opts = {
                virt_text = true,
                virt_text_pos = 'right_align',
                delay = 1000,
                ignore_whitespace = false,
            },
        },
    }
}
