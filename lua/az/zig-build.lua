local M = {}

-- Build commands for Zig
local function zig_build()
	vim.cmd("FloatermNew zig build -Doptimize=Debug")
	vim.schedule(function()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true),
			"n",
			false
		)
	end)
end

local function zig_rebuild()
	vim.cmd("FloatermNew rm -rf ./zig-out && zig build -Doptimize=Debug")
	vim.schedule(function()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true),
			"n",
			false
		)
	end)
end

local function zig_clean_rebuild()
	vim.cmd("FloatermNew rm -rf zig-out && rm -rf .zig-cache && zig build -Doptimize=Debug")
	vim.schedule(function()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true),
			"n",
			false
		)
	end)
end

-- Check if current directory is a Zig project by searching for build.zig in current and parent directories
local function is_zig_project()
	local bufnr = vim.api.nvim_get_current_buf()
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		return false
	end
	local dir = vim.fn.fnamemodify(filepath, ':h')

	-- Search for build.zig in current directory and parent directories
	local max_depth = 5
	for depth = 0, max_depth do
		local build_file = dir .. '/build.zig'
		local exists = vim.fn.filereadable(build_file) == 1
		if exists then
			return true
		end

		-- Move to parent directory
		local parent = vim.fn.fnamemodify(dir, ':h')
		if parent == dir then
			break  -- Reached root
		end
		dir = parent
	end

	return false
end

-- Setup Zig build commands for current buffer
function M.setup_buffer()
	if not is_zig_project() then
		return
	end

	-- Create buffer-local keymaps
	local opts = { buffer = true, desc = "Zig: Build project" }
	local rebuild_opts = { buffer = true, desc = "Zig: Rebuild project" }
	local clean_opts = { buffer = true, desc = "Zig: Clean rebuild" }

	vim.keymap.set("n", "<leader>zb", zig_build, opts)
	vim.keymap.set("n", "<leader>zr", zig_rebuild, rebuild_opts)
	vim.keymap.set("n", "<leader>zc", zig_clean_rebuild, clean_opts)
end

-- Setup autocmd to detect Zig projects
function M.setup()
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function(args)
			if is_zig_project() then
				M.setup_buffer()
			end
		end,
	})
end

return M
