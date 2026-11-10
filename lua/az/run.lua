local M = {}

local EXE = "./zig-out/bin/c"

local items = {
	{ label = "--particles-only", flag = "--particles-only" },
	{ label = "--replay", replay = true },
	{ label = "--debug-emit", flag = "--debug-emit" },
}

local function run_flag(flag)
	local root = vim.fn.getcwd()
	local cmd = ("cd %s && %s %s"):format(
		vim.fn.shellescape(root),
		EXE,
		flag
	)

	vim.cmd("FloatermNew --position=bottomright --width=0.5 --height=0.3 --autoclose=0 " .. cmd)

	vim.schedule(function()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-\\><C-n><C-w>w", true, true, true),
			"n",
			false
		)
	end)
end

function M.pick()
	vim.ui.select(items, {
		prompt = "Run",
		format_item = function(item)
			return item.label
		end,
		snacks = {
			-- Start focused on the list so j/k work immediately.
			focus = "list",
		},
	}, function(item)
		if not item then
			return
		end

		if item.replay then
			require("az.replay").pick()
		else
			run_flag(item.flag)
		end
	end)
end

function M.setup()
	vim.keymap.set("n", "<leader><leader><leader>", M.pick, { desc = "Run: pick flag" })
end

return M
