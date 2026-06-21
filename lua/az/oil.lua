vim.pack.add { "https://github.com/stevearc/oil.nvim" }
require("oil").setup({
	skip_confirm_for_simple_edits = true,
	keymaps = {
		--remove Ctrl S from oil so global can use it for save
		["<C-s>"] = false,
	},
	float = {
		max_width = 0.80,
		max_height = 0.80,
		border = "rounded",
		padding = 2,
		win_options = {
			winblend = 0,
		},
		--	override = function(conf)
		--		conf.col = 18 -- Position near left edge
		--		return conf
		--	end,	
	},


})

-- Open oil as floating window over terminal using current project directory
vim.keymap.set("n", "-", function()
	require("oil").open_float()
end)






-- !!! Dev notes turn this on for alt unified ecosystem flow because oil keeps bringing up ~/
-- Override :Oil command to use current directory instead of parsing buffer name
--vim.api.nvim_create_user_command("Oil", function(opts)
--  local dir = opts.fargs[1] or vim.fn.getcwd()
--  require("oil").open(dir)
--end, { nargs = "?", complete = "dir", desc = "Open oil in current directory" })



-- !!! Devnotes this is for a dual popup setting of a tree + oil
-- State tracking for oil+tree combo
--local oil_tree_open = false
--local tree_floaterm_name = "oil_tree"
---- Toggle function for oil + tree preview
--local function toggle_oil_tree()
--	local cwd = vim.fn.getcwd()
--
--	if oil_tree_open then
--		-- Close both windows
--		pcall(function()
--			require("oil").close()
--		end)
--		vim.cmd("FloatermKill!" .. tree_floaterm_name)
--		oil_tree_open = false
--		vim.cmd("stopinsert")
--	else
--
--		-- Open tree on right with short delay to ensure oil renders first
--		vim.cmd(string.format(
--			"FloatermNew --name=%s --width=0.4 --position=right --autoclose=0 --autoinsert=0 tree %s",
--			tree_floaterm_name,
--			vim.fn.shellescape(cwd)
--		))
--		oil_tree_open = true
--
--		-- Open oil on left
--		require("oil").open_float(cwd)
--		vim.cmd("stopinsert")
--
--	end
--end
---- Keymap for synchronized toggle
--vim.keymap.set("n", "<leader>e", toggle_oil_tree, { desc = "Toggle oil + tree preview" })
---- Cleanup function to close both if neovim closes
--vim.api.nvim_create_autocmd("VimLeavePre", {
--	callback = function()
--		if oil_tree_open then
--			vim.cmd("FloatermKill!" .. tree_floaterm_name)
--		end
--	end,
--})
