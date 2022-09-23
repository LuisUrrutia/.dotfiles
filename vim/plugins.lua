vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'
  use 'tpope/vim-surround'
  use 'easymotion/vim-easymotion'
end)
