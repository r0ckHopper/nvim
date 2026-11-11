local M = {}

local base_items = {
	{ label = "none", args = {}},
	{ label = "--particles-only", args = { "--particles-only" } },
	{ label = "--replay", replay = true },
	{ label = "--debug-emit", args = { "--debug-emit" } },
}

local function split_args(input)
	local trimmed = vim.trim(input or "")
	if trimmed == "" then
		return {}
	end
	return vim.split(trimmed, "%s+", { trimempty = true })
end

-- opts:
--   none    - include a "No args" entry
--   custom  - include a "Custom..." entry
--   prompt  - picker prompt
-- cb receives an args table, e.g. { "--replay", "replays/foo.r1" },
-- or nil if the user cancels.
function M.pick(opts, cb)
	opts = opts or {}

	local items = {}
	if opts.none then
		items[#items + 1] = { label = "No args", args = {} }
	end
	vim.list_extend(items, base_items)
	if opts.custom then
		items[#items + 1] = { label = "Custom...", custom = true }
	end

	vim.ui.select(items, {
		prompt = opts.prompt or "Args",
		format_item = function(item)
			return item.label
		end,
		snacks = {
			focus = "list",
		},
	}, function(item)
		if not item then
			cb(nil)
			return
		end

		if item.replay then
			require("az.replay").select(function(replay)
				if replay then
					cb({ "--replay", replay.rel })
				else
					cb(nil)
				end
			end)
		elseif item.custom then
			vim.ui.input({ prompt = "Args: " }, function(input)
				if input == nil then
					cb(nil)
					return
				end
				cb(split_args(input))
			end)
		else
			cb(item.args)
		end
	end)
end

return M
