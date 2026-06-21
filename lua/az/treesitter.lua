vim.pack.add({
	"https://github.com/nvim-treesitter/nvim-treesitter",
})

require'nvim-treesitter'.setup{

	install_dir = vim.fn.stdpath('data') .. '/site'
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

---- 4️⃣ Folding: enable Treesitter-based folding
--vim.api.nvim_create_autocmd('FileType', {
--  pattern = { 'lua', 'zig', 'sc' },
--  callback = function()
--    vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
--    vim.wo[0][0].foldmethod = 'expr'
--  end,
--})

-- 5️⃣ Indentation: enable Treesitter-based indentation
vim.api.nvim_create_autocmd('FileType', {
	pattern = { 'lua', 'zig', 'sc' },
	callback = function()
		vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
	end,
})

