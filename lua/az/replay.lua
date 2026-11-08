local M = {}

local EXE = "./zig-out/bin/c"

local function list_replays()
	local dir = vim.fn.getcwd() .. "/replays"

	if vim.fn.isdirectory(dir) == 0 then
		vim.notify("No replays/ directory in " .. vim.fn.getcwd(), vim.log.levels.WARN)
		return {}
	end

	local items = {}
	for name, kind in vim.fs.dir(dir) do
		-- Remove the .r1 match if you want to list every file in replays/
		if kind == "file" and name:match("%.r1$") then
			items[#items + 1] = {
				name = name,
				rel = "replays/" .. name,
			}
		end
	end

	table.sort(items, function(a, b)
		return a.name < b.name
	end)

	return items
end

local function run_replay(rel)
	local root = vim.fn.getcwd()
	local cmd = ("cd %s && %s --replay %s"):format(
		vim.fn.shellescape(root),
		EXE,
		vim.fn.shellescape(rel)
	)

	vim.cmd(
		"FloatermNew --position=bottomright --width=0.5 --height=0.3 --autoclose=0 " .. cmd
	)

	vim.schedule(function()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true),
			"n",
			false
		)
	end)
end

function M.pick()
	local items = list_replays()
	if #items == 0 then
		return
	end

	vim.ui.select(items, {
		prompt = "Replay",
		format_item = function(item)
			return item.name
		end,
		-- Start focused on the list so j/k move immediately.
		-- Press i to focus the filter input.
		snacks = { focus = "list" },
	}, function(item)
		if item then
			run_replay(item.rel)
		end
	end)
end

function M.setup()
	vim.keymap.set("n", "<leader><leader>r", M.pick, { desc = "Replay: pick and run" })
end

return M
