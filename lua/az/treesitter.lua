vim.pack.add({
	"https://github.com/nvim-treesitter/nvim-treesitter",
})

vim.cmd('packadd nvim-treesitter')
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/site/pack/core/opt/nvim-treesitter/runtime')

require'nvim-treesitter'.setup{

	install_dir = vim.fn.stdpath('data') .. '/site',
	indent = { enable = true },
}

require'nvim-treesitter'.install { 'zig', 'lua' , 'glsl'}

vim.treesitter.language.register('glsl', 'sc')

-- 3️⃣ Highlighting: start Treesitter on specific filetypes
vim.api.nvim_create_autocmd('FileType', {
	pattern = { 'lua', 'zig', 'sc' },  -- replace or add any filetypes you want
	callback = function()
		vim.treesitter.start()
	end,
})
