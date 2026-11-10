local M = {}

local EXE = "./zig-out/bin/c"

local function run(args)
	local root = vim.fn.getcwd()
	local parts = { EXE }
	for _, arg in ipairs(args) do
		parts[#parts + 1] = vim.fn.shellescape(arg)
	end

	local cmd = ("cd %s && %s"):format(
		vim.fn.shellescape(root),
		table.concat(parts, " ")
	)

	vim.cmd(
		"FloatermNew --position=bottomright --width=0.5 --height=0.3 --autoclose=0 " .. cmd
	)

	vim.schedule(function()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-\\><C-n><C-w>w", true, true, true),
			"n",
			false
		)
	end)
end

function M.pick()
	require("az.args").pick({}, function(args)
		if args then
			run(args)
		end
	end)
end

function M.setup()
	vim.keymap.set("n", "<leader><leader><leader>", M.pick, { desc = "Run: pick flag" })
end

return M
