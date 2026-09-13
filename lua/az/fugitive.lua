vim.pack.add({
	"https://github.com/tpope/vim-fugitive"
})
vim.keymap.set('n', "<leader>gg", ':G | only<CR>');

-- Populate quickfix with all unstaged file paths
vim.keymap.set('n', '<leader>gU', function()
  local files = vim.fn.systemlist('git diff --name-only')
  if vim.tbl_isempty(files) then
    vim.notify('No unstaged changes', vim.log.levels.INFO)
    return
  end
  vim.fn.setqflist({}, ' ', { title = 'Unstaged Files', lines = files })
  vim.cmd('cwindow')
end, { desc = 'Fugitive: unstaged files into quickfix' })

--fugitiveHeader xxx links to Label
--fugitiveHash   xxx links to Identifier
--fugitiveSymbolicRef xxx links to Function
--fugitiveHelpTag xxx links to Tag
--fugitiveHelpHeader xxx links to fugitiveHeader
--fugitiveHeading xxx links to PreProc
--fugitiveSection xxx cleared
--fugitivePreposition xxx cleared
--fugitiveCount  xxx links to Number
--fugitiveInstruction xxx links to Type
--fugitiveDone   xxx cleared
--fugitiveStop   xxx links to Function
--fugitiveModifier xxx links to Type
--do highlights later

local function set_fugitive_colors()

--DiffAdd        xxx cterm=bold gui=bold guifg=#ffffff guibg=#33ff00
--DiffChange     xxx guibg=#0066ff
--DiffDelete     xxx cterm=bold gui=bold guifg=#ff0000
--DiffText       xxx cterm=bold gui=bold guifg=#ffffff guibg=#0066ff
	vim.api.nvim_set_hl(0, 'DiffAdd', {
		fg = '#ffffff',       
		bg='#447a44',
		bold = true,
		ctermfg = 42,
		sp = '#33ff00',
		blend =90,
		--undercurl = true,
		--underline = true,
		--underdotted = true,
		--underdashed = true,
		--gui = 'underline',
		--cterm = 'underline'
	})
	vim.api.nvim_set_hl(0, 'DiffChange', {
		--fg = '#ff0000',        -- Natural blue
		bg = '#00009f',
		ctermfg = 75,
		--gui = 'underline',
		--cterm = 'underline'
	})
	vim.api.nvim_set_hl(0, 'DiffText', {
		fg = '#ff0000',        -- White text
		bg = '#0000ff',        -- Very dark gray background
		--underdashed = true,
		sp = '#33ff00',
		--gui = 'none',
		--cterm = 'none'
	})
end

set_fugitive_colors()
-- Reapply after colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = set_fugitive_colors,
})























local function open_fugitive_float()
	-- Open fugitive
	vim.cmd('Gedit')

	-- Wait a moment for the buffer to open
	vim.defer_fn(function()
		local fugitive_buf = vim.fn.bufnr('^fugitive://')
		if fugitive_buf ~= -1 then
			local opts = {
				relative = 'editor',
				width = math.floor(vim.o.columns * 0.8),
				height = math.floor(vim.o.lines * 0.8),
				row = math.floor(vim.o.lines * 0.1),
				col = math.floor(vim.o.columns * 0.1),
				style = 'minimal',
				border = 'rounded'
			}
			vim.api.nvim_open_win(fugitive_buf, true, opts)
		end
	end, 10)
end
vim.api.nvim_create_user_command('Gfloat', open_fugitive_float, {})

