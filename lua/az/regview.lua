-- Toggleable, non-focusable `:registers` viewer pinned to the top-right.
-- Toggle with `""` (or :RegView).

local M = {}

local ns = vim.api.nvim_create_namespace("az.regview")
local state = { buf = nil, win = nil, pending = false }

local function register_lines()
	local ok, result = pcall(vim.api.nvim_exec2, "registers", { output = true })
	local lines
	if ok and result and result.output then
		lines = vim.split(result.output, "\n", { plain = true })
	else
		lines = { "registers unavailable" }
	end

	-- Drop the clipboard-provider diagnostic; it is noise, not register content.
	local filtered = {}
	for _, line in ipairs(lines) do
		if not line:match("^clipboard: error:") then
			filtered[#filtered + 1] = line
		end
	end
	while #filtered > 0 and filtered[#filtered] == "" do
		table.remove(filtered)
	end
	if #filtered == 0 then
		filtered = { "Type Name Content" }
	end
	return filtered
end

local function dimensions(lines)
	local max_width = 0
	for _, line in ipairs(lines) do
		max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
	end

	local width = math.max(24, math.min(max_width + 1, math.floor(vim.o.columns * 0.55)))
	width = math.min(width, vim.o.columns - 4)

	local height = math.min(#lines, math.max(4, math.floor(vim.o.lines * 0.6)))
	height = math.max(1, math.min(height, vim.o.lines - 4))

	return width, height
end

local function highlight(buf, lines)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for i, line in ipairs(lines) do
		local row = i - 1
		if i == 1 then
			vim.api.nvim_buf_add_highlight(buf, ns, "Title", row, 0, -1)
		else
			local regtype = line:match("^%s+([clb])%s")
			if regtype then
				local start = line:find(regtype, 1, true) - 1
				vim.api.nvim_buf_add_highlight(buf, ns, "Special", row, start, start + 1)
			end
			local quote = line:find('"', 1, true)
			if quote then
				vim.api.nvim_buf_add_highlight(buf, ns, "Identifier", row, quote - 1, quote + 1)
			end
		end
	end
end

local function is_visible()
	return state.win ~= nil
		and vim.api.nvim_win_is_valid(state.win)
		and vim.api.nvim_win_get_tabpage(state.win) == vim.api.nvim_get_current_tabpage()
end

function M.open()
	local lines = register_lines()
	local width, height = dimensions(lines)

	if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
		state.buf = vim.api.nvim_create_buf(false, true)
	end
	local buf = state.buf

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].undolevels = -1
	highlight(buf, lines)

	local config = {
		relative = "editor",
		anchor = "NE",
		row = 1,
		col = vim.o.columns - 2,
		width = width,
		height = height,
		focusable = false,
		style = "minimal",
		border = "rounded",
		title = " registers ",
		title_pos = "center",
		zindex = 60,
	}

	local win = state.win
	local same_tab = win
		and vim.api.nvim_win_is_valid(win)
		and vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage()

	if same_tab then
		vim.api.nvim_win_set_config(win, config)
	else
		if win and vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
		state.win = vim.api.nvim_open_win(buf, false, config)
	end
end

function M.close()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		pcall(vim.api.nvim_win_close, state.win, true)
	end
	state.win = nil
end

function M.toggle()
	if is_visible() then
		M.close()
	else
		M.open()
	end
end

local function refresh()
	if is_visible() then
		M.open()
	end
end

local function refresh_soon()
	if state.pending then
		return
	end
	state.pending = true
	vim.schedule(function()
		state.pending = false
		refresh()
	end)
end

function M.setup()
	local group = vim.api.nvim_create_augroup("az_regview", { clear = true })
	vim.api.nvim_create_autocmd({
		"TextYankPost",
		"CmdlineLeave",
		"RecordingEnter",
		"RecordingLeave",
		"InsertLeave",
		"FocusGained",
		"VimResized",
		"TabEnter",
	}, {
		group = group,
		callback = refresh_soon,
		desc = "Refresh the register viewer",
	})

	vim.keymap.set("n", '""', M.toggle, { desc = "Toggle register viewer" })
	vim.api.nvim_create_user_command("RegView", M.toggle, { desc = "Toggle register viewer" })
end

return M
