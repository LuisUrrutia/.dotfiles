vimFolder = vim.fn.stdpath("config")

vim.env.NVIM_TUI_ENABLE_TRUE_COLOR = 1

-- GLOBAL OPTIONS
vim.g.mapleader = ','
vim.g.material_style = 'oceanic'


vim.o.autoread = true                 -- autom. read file when changed outside of Vim
vim.o.background = "dark"             -- used for highlight colors
vim.o.backspace = "indent,eol,start"  -- how backspace works at start of line
vim.o.backup = false                  -- keep backup file after overwriting a file
vim.o.hidden = true                   -- don't unload buffer when it is
vim.o.history = 1000                  -- number of command-lines that are remembered
vim.o.hlsearch = true                 -- highlight matches with last search pattern
vim.o.ignorecase = true               -- ignore case in search patterns
vim.o.inccommand = 'nosplit'          -- Live preview of substitution
vim.o.incsearch = true                -- highlight match while typing search pattern
vim.o.sidescroll = 1                  -- minimum number of columns to scroll horizontal
vim.o.sidescrolloff = 15              -- min. nr. of columns to left and right of cursor
vim.o.scrolloff = 8                   -- minimum nr. of lines above and below cursor
vim.o.showcmd = true                  -- show (partial) command in status line
vim.o.showmatch = true                -- briefly jump to matching bracket if insert one
vim.o.showmode = true                 -- message on status line to show current mode
vim.o.smartcase = true                -- no ignore case when pattern has uppercase
vim.o.smarttab = true                 -- use 'shiftwidth' when inserting <Tab>
vim.o.visualbell = true               -- use visual bell instead of beepingA
vim.o.wildmenu = true                 -- use menu for command line completion
vim.o.wildmode = "list:longest"       -- mode for 'wildchar' command-line expansion
vim.o.writebackup = false             -- make a backup before overwriting a file

if (vim.fn.has('termguicolors') == 1) then
	vim.opt.termguicolors = true
end

-- files matching these patterns are not completed
vim.o.wildignore = vim.o.wildignore..table.concat({
  '*.o','*.obj','.git','*.rbc','*.pyc','__pycache__','*~','*.class',
  '*.git/*','*.hg/*','*.svn/*','*DS_Store*',
  '*/node_modules/*','*/.dist/*','*/.coverage/*'
})


vim.wo.foldenable = false     -- set to display all folds open
vim.wo.foldmethod = "indent"  -- folding type
vim.wo.foldnestmax = 3        -- maximum fold depth
vim.wo.linebreak = true       -- wrap long lines at a blank
vim.wo.number = true          -- print the line number in front of each line
vim.wo.wrap = false           -- lines wrap and continue on the next line

vim.bo.expandtab = true -- use spaces when <Tab> is inserted
vim.bo.shiftwidth = 2   -- number of spaces to use for (auto)indent step
vim.bo.softtabstop = 2  -- number of spaces that <Tab> uses while editing
vim.bo.swapfile = false -- whether to use a swapfile for a buffer
vim.bo.tabstop = 2      -- number of spaces that <Tab> in file uses

vim.cmd("colorscheme vim-material")

-- save undo information in a file
if vim.fn.has("persistent_undo") == 1 then
  if vim.fn.isdirectory(vimFolder.."/undo") == 0 then
    vim.fn.mkdir(vimFolder.."/undo")
  end

  vim.opt.undofile = true
  vim.opt.undodir = vimFolder.."/undo"
end

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]])

require("plugins")
