vim.pack.add{ "https://github.com/chrisgrieser/nvim-origami" }

-- prevent nvim autofolding recommended by nvim origami

vim.opt.foldlevel = 2
vim.opt.foldlevelstart = 99

vim.opt.foldcolumn = "1"
--vim.opt.fillchars = {
--	foldopen = "v"
--}

require("origami").setup()

-- persistent folds across sessions (mkview / loadview)

local folds_grp = vim.api.nvim_create_augroup("origami_folds", { clear = true })

vim.api.nvim_create_autocmd("BufWinLeave", {
	group = folds_grp,
	pattern = "*",
	callback = function()
		if vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
			vim.cmd("silent! mkview")
		end
	end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
	group = folds_grp,
	pattern = "*",
	callback = function()
		if vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
			vim.cmd("silent! loadview")
		end
	end,
})
