local M = {}

local EXE = "./zig-out/bin/c"

function M.list()
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
			vim.api.nvim_replace_termcodes("<C-\\><C-n><C-w>w", true, true, true),
			"n",
			false
		)
	end)
end

-- Opens the replay picker and calls cb with the selected replay entry,
-- or nil if the user cancels.
function M.select(cb)
	local items = M.list()
	if #items == 0 then
		cb(nil)
		return
	end

	local function copy_replay(picker)
		local entry = picker:current()
		local replay = entry and entry.item
		if not replay then
			return
		end

		vim.fn.setreg("+", replay.name)
		vim.notify("Copied " .. replay.name, vim.log.levels.INFO)
	end

	local function delete_replay(picker)
		local entry = picker:current()
		local replay = entry and entry.item
		if not replay then
			return
		end

		local path = vim.fs.joinpath(vim.fn.getcwd(), replay.rel)

		-- dd deletes immediately; no confirmation prompt.
		if vim.fn.delete(path) ~= 0 then
			vim.notify("Failed to delete " .. replay.name, vim.log.levels.ERROR)
			return
		end

		for i, item in ipairs(items) do
			if item == replay then
				table.remove(items, i)
				break
			end
		end

		if #items == 0 then
			picker:close()
		else
			picker:find()
		end
	end

	vim.ui.select(items, {
		prompt = "Replay",
		format_item = function(item)
			return item.name
		end,
		snacks = {
			-- Start focused on the list so j/k and yy/dd work immediately.
			-- Press i to focus the filter input.
			focus = "list",
			actions = {
				copy_replay = copy_replay,
				delete_replay = delete_replay,
			},
			win = {
				list = {
					keys = {
						["yy"] = "copy_replay",
						["dd"] = "delete_replay",
					},
				},
			},
		},
	}, function(item)
		cb(item)
	end)
end

function M.pick()
	M.select(function(item)
		if item then
			run_replay(item.rel)
		end
	end)
end

function M.setup()
	vim.keymap.set("n", "<leader><leader>r", M.pick, { desc = "Replay: pick and run" })
end

return M
