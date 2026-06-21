vim.pack.add({
	"https://github.com/lewis6991/gitsigns.nvim"
})

require('gitsigns').setup {
	on_attach = function(bufnr)
		local gs = package.loaded.gitsigns

		local function map(mode, l, r, opts)
			opts = opts or {}
			opts.buffer = bufnr
			vim.keymap.set(mode, l, r, opts)
		end

		-- Navigation
		map('n', ']]', function()
			if vim.wo.diff then return ']c' end
			vim.schedule(function() gs.next_hunk() end)
			return '<Ignore>'
		end, {expr=true})

		map('n', '[[', function()
			if vim.wo.diff then return '[c' end
			vim.schedule(function() gs.prev_hunk() end)
			return '<Ignore>'
		end, {expr=true})

		-- Actions
		map('n', '<leader>gs', gs.stage_hunk, { desc = 'Stage hunk' })
		map('n', '<leader>gr', gs.reset_hunk, { desc = 'Reset hunk' })
		map('n', '<leader>gS', gs.stage_buffer, { desc = 'Stage buffer' })
		map('n', '<leader>gu', gs.undo_stage_hunk, { desc = 'Unstage hunk' })
		map('n', '<leader>gR', gs.reset_buffer, { desc = 'Reset buffer' })
		map('n', '<leader>gp', gs.preview_hunk, { desc = 'Preview hunk' })
		map('n', '<leader>gb', function() gs.blame_line({full=true}) end, { desc = 'Blame line' })
		map('n', '<leader>gb', gs.toggle_current_line_blame, { desc = 'Toggle blame' })
		map('n', '<leader>gd', gs.diffthis, { desc = 'Diff this' })
		map('n', '<leader>gD', function() gs.diffthis('~') end, { desc = 'Diff this ~' })
		map('n', '<leader>gt', function() gs.toggle_deleted() gs.toggle_word_diff() gs.toggle_numhl() end, { desc = 'toggle gitdiff' })
		map('n', '<leader>gl', function() gs.toggle_linehl() end, { desc = 'Toggle Gitdiff' })

		-- Text object
		map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = 'Select hunk' })
	end,
	signs = {
		add          = { text = '┃' },
		change       = { text = '┃' },
		delete       = { text = '_' },
		topdelete    = { text = '‾' },
		changedelete = { text = '~' },
		untracked    = { text = '┆' },
	},
	signs_staged = {
		add          = { text = '┃┃' },
		change       = { text = '┃┃' },
		delete       = { text = '_' },
		topdelete    = { text = '‾' },
		changedelete = { text = '~' },
		untracked    = { text = '┆' },
	},
	signs_staged_enable = true,
	signcolumn = true,  -- Toggle with `:Gitsigns toggle_signs`
	numhl      = false, -- Toggle with `:Gitsigns toggle_numhl`
	linehl     = false, -- Toggle with `:Gitsigns toggle_linehl`
	word_diff  = false, -- Toggle with `:Gitsigns toggle_word_diff`
	watch_gitdir = {
		follow_files = true
	},
	auto_attach = true,
	attach_to_untracked = false,
	current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
	current_line_blame_opts = {
		virt_text = true,
		virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
		delay = 1000,
		ignore_whitespace = false,
		virt_text_priority = 100,
		use_focus = true,
	},
	current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',
	sign_priority = 6,
	update_debounce = 100,
	status_formatter = nil, -- Use default
	max_file_length = 40000, -- Disable if file is longer than this (in lines)
	preview_config = {
		-- Options passed to nvim_open_win
		style = 'minimal',
		relative = 'cursor',
		row = 0,
		col = 1
	},
}

local function set_gitsigns_colors()
	vim.api.nvim_set_hl(0, 'GitSignsAdd', { link = "Type" })
	vim.api.nvim_set_hl(0, 'GitSignsStagedAdd', { link = "Type" })
	--vim.api.nvim_set_hl(0, 'GitSignsStagedUntracked', { link = "Type" })
	vim.api.nvim_set_hl(0, 'GitSignsStagedAddNr', { link = "Type" })
	--vim.api.nvim_set_hl(0, 'GitSignsStagedUntrackedNr', { link = "Type" })


	vim.api.nvim_set_hl(0, 'GitSignsChange', { link = "Constant" })
	vim.api.nvim_set_hl(0, 'GitSignsStagedChange', { link = "Constant" })
	--vim.api.nvim_set_hl(0, 'GitSignsStagedUntracked', { link = "Constant" })
	vim.api.nvim_set_hl(0, 'GitSignsStagedChangeNr', { link = "Constant" })
	--vim.api.nvim_set_hl(0, 'GitSignsStagedUntrackedNr', { link = "Constant" })
	

	vim.api.nvim_set_hl(0, 'GitSignsDelete', { link = "DiffDelete" })
end

set_gitsigns_colors()
-- Reapply after colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = set_gitsigns_colors,
})

