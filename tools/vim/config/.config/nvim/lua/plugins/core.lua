return {
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate"
    },
    {
        "nvim-treesitter/nvim-treesitter-context",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
    },
    {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release --target install'
    },
    {
        'nvim-telescope/telescope-frecency.nvim',
        version = "*",
    },
    {
        'nvim-telescope/telescope.nvim',
        tag = 'v0.2.0',
        dependencies = {
            'nvim-lua/plenary.nvim',
            'nvim-telescope/telescope-fzf-native.nvim',
            'nvim-telescope/telescope-frecency.nvim'
        },
        config = function()
            require('telescope').setup({
                defaults = {
                    vimgrep_arguments = {
                        'rg',
                        '--color=never',
                        '--no-heading',
                        '--with-filename',
                        '--line-number',
                        '--column',
                        '--smart-case',
                        '--follow',
                        '--hidden',
                        '--glob=!.git'
                    },
                },
                pickers = {
                    find_files = {
                        -- custom command because some of my projects have hidden files/folders
                        -- so I want to see them, with .git exception
                        find_command = {
                            'fd',
                            '--type=f',
                            '--follow',
                            '--hidden',
                            '--exclude=.git',
                            '--color=never'
                        }
                    }
                },
                extensions = {
                    frecency = {
                        auto_validate = false,
                        show_scores = false,
                    },
                    fzf = {
                        fuzzy = true,
                        override_generic_sorter = true,
                        override_file_sorter = true,
                        case_mode = "smart_case",
                    }
                }
            })
            require('telescope').load_extension('fzf')
            require('telescope').load_extension('frecency')
            require("telescope").load_extension("fidget")

            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<C-p>', builtin.git_files, { desc = 'Search git files' })
            vim.keymap.set('n', '<leader>sf', ':Telescope frecency workspace=CWD<CR>', { desc = '[S]earch [F]iles' })
            vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
            vim.keymap.set('n', '<leader>ss', builtin.grep_string, { desc = '[S]earch by [S]tring' })
            vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
        end
    },
    {
        -- Use :Git
        'tpope/vim-fugitive',
        config = function()
            -- Config stolen from https://github.com/ThePrimeagen/init.lua/blob/master/lua/theprimeagen/lazy/fugitive.lua
            vim.keymap.set("n", "<leader>gs", vim.cmd.Git)

            local ThePrimeagen_Fugitive = vim.api.nvim_create_augroup("ThePrimeagen_Fugitive", {})

            local autocmd = vim.api.nvim_create_autocmd
            autocmd("BufWinEnter", {
                group = ThePrimeagen_Fugitive,
                pattern = "*",
                callback = function()
                    if vim.bo.ft ~= "fugitive" then
                        return
                    end

                    local bufnr = vim.api.nvim_get_current_buf()
                    local opts = { buffer = bufnr, remap = false }

                    vim.keymap.set("n", "<leader>p", function()
                        vim.cmd.Git('push')
                    end, opts)

                    -- rebase always
                    vim.keymap.set("n", "<leader>P", function()
                        vim.cmd.Git({ 'pull', '--rebase' })
                    end, opts)

                    -- NOTE: It allows me to easily set the branch i am pushing and any tracking
                    -- needed if i did not set the branch up correctly
                    vim.keymap.set("n", "<leader>t", ":Git push -u origin ", opts);
                end,
            })


            vim.keymap.set("n", "gu", "<cmd>diffget //2<CR>")
            vim.keymap.set("n", "gh", "<cmd>diffget //3<CR>")
        end
    },
    {
        "j-hui/fidget.nvim",
        opts = {
            -- options
        },
    }
}
