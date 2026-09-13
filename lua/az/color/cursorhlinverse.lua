local cursor_default_bg = '#00ff00'
local cursor_default_fg = '#00ff00'

local function set_colors()
	vim.api.nvim_set_hl(0, 'Cursor', {
		bg = cursor_default_bg,
		fg = cursor_default_fg,
	})
	vim.api.nvim_set_hl(0, 'CursorLine', {
		bg = '#000099',
	})
	vim.api.nvim_set_hl(0, 'CursorLineNr', {
		bg = NONE,
		fg = '#ffff00'
	})
	vim.api.nvim_set_hl(0, 'LineNr', {
		bg = NONE,
	})
end

set_colors()
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = set_colors,
})

local function invert_color(hex)
	hex = hex:gsub('#', '')
	local r = 255 - tonumber(hex:sub(1, 2), 16)
	local g = 255 - tonumber(hex:sub(3, 4), 16)
	local b = 255 - tonumber(hex:sub(5, 6), 16)
	return string.format('#%02x%02x%02x', r, g, b)
end

local function hl_to_hex(color)
	if type(color) == 'number' then
		return string.format('#%06x', color)
	elseif type(color) == 'string' and color:match('^#%x%x%x%x%x%x$') then
		return color
	end
end

local function resolve_hl(name)
	local hl = vim.api.nvim_get_hl(0, { name = name })
	while hl.link do
		hl = vim.api.nvim_get_hl(0, { name = hl.link })
	end
	return hl
end

local function get_fg_at_pos(buf, row0, col)
	local syn_id = vim.fn.synID(row0, col + 1, 1)
	local trans_id = vim.fn.synIDtrans(syn_id)
	local fg_str = vim.fn.synIDattr(trans_id, 'fg', 'gui')
	if fg_str ~= '' then return fg_str end

	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then return nil end
	local tree = parser:parse()[1]
	if not tree then return nil end
	local ft = vim.bo[buf].filetype
	local query = vim.treesitter.query.get(ft, 'highlights')
	if not query then return nil end

	local best_len = math.huge
	local best_fg = nil
	for id, node in query:iter_captures(tree:root(), buf, row0 - 1, row0) do
		local sr, sc, er, ec = node:range()
		if sr == row0 - 1 and col >= sc and col < ec then
			local len = ec - sc
			if len < best_len then
				best_len = len
				local hl = resolve_hl('@' .. query.captures[id])
				best_fg = hl.fg and hl_to_hex(hl.fg)
			end
		end
	end
	return best_fg
end

local function get_gitsigns_word_diff_color(buf, row, col)
	local ok_cache, gs_cache = pcall(require, 'gitsigns.cache')
	if not ok_cache then return nil end
	local ok_cfg, gs_cfg = pcall(require, 'gitsigns.config')
	if not ok_cfg or not gs_cfg.config.word_diff then return nil end

	local bcache = gs_cache.cache[buf]
	if not bcache or not bcache.hunks then return nil end

	local ok_h, Hunks = pcall(require, 'gitsigns.hunks')
	if not ok_h then return nil end

	local hunk = Hunks.find_hunk(row, bcache.hunks)
	if not hunk then return nil end
	if hunk.added.count ~= hunk.removed.count then return nil end

	local pos = row - hunk.added.start + 1
	local added_line = hunk.added.lines[pos]
	local removed_line = hunk.removed.lines[pos]
	if not added_line or not removed_line then return nil end

	local ok_d, diff_int = pcall(require, 'gitsigns.diff_int')
	if not ok_d then return nil end

	local _, regions = diff_int.run_word_diff({ removed_line }, { added_line })
	for _, region in ipairs(regions or {}) do
		local scol = region[3] - 1
		local ecol = region[4] - 1
		if col >= scol and col < ecol then
			local rtype = region[2]
			local hl_name = rtype == 'add' and 'GitSignsAddLnInline'
				or rtype == 'change' and 'GitSignsChangeLnInline'
				or 'GitSignsDeleteLnInline'
			local hl = resolve_hl(hl_name)
			if hl.reverse then
				local fg = get_fg_at_pos(buf, row, col)
				if fg then return fg end
			end
			return hl.bg and hl_to_hex(hl.bg) or hl.fg and hl_to_hex(hl.fg)
		end
	end
	return nil
end

local current_cursor_bg = cursor_default_bg

local function update_cursor_color()
	local buf = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))

	local found_color = nil
	local best_priority = -1

	local ok, extmarks = pcall(vim.api.nvim_buf_get_extmarks, buf, -1,
		{ row - 1, col }, { row - 1, col }, { details = true, overlap = true })

	if ok and extmarks then
		for _, mark in ipairs(extmarks) do
			local details = mark[4]
			if details and details.hl_group then
				local priority = details.priority or 0
				if priority > best_priority then
					local hl = resolve_hl(details.hl_group)
					local bg = hl.bg and hl_to_hex(hl.bg)
					local fg = hl.fg and hl_to_hex(hl.fg)
					if bg or fg then
						best_priority = priority
						found_color = bg or fg
					end
				end
			end
		end
	end

	if not found_color then
		found_color = get_gitsigns_word_diff_color(buf, row, col)
	end

	if not found_color then
		local syn_id = vim.fn.synID(row, col + 1, 1)
		local trans_id = vim.fn.synIDtrans(syn_id)
		local name = vim.fn.synIDattr(trans_id, 'name')
		if name ~= '' and name ~= 'Normal' then
			local hl = resolve_hl(name)
			found_color = (hl.bg and hl_to_hex(hl.bg)) or (hl.fg and hl_to_hex(hl.fg))
		end
	end

	local new_bg = found_color and invert_color(found_color) or cursor_default_bg
	local new_fg = found_color or cursor_default_fg

	if new_bg ~= current_cursor_bg then
		current_cursor_bg = new_bg
		vim.api.nvim_set_hl(0, 'Cursor', { bg = new_bg, fg = new_fg })
	end
end

vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'WinEnter' }, {
	callback = update_cursor_color,
})
