vim.pack.add{ "https://github.com/chrisgrieser/nvim-origami" }

-- prevent nvim autofolding recommended by nvim origami

vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

vim.opt.foldcolumn = "1"
--vim.opt.fillchars = {
--	foldopen = "v"
--}

require("origami").setup()

