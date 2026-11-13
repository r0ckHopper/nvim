-- Yank into a register, with the register chosen after the motion.
--
--   <C-y>w a    yank word into a
--   <C-y>i( b   yank inside parens into b
--   <C-y>y a    yank line into a
--   <C-y>j A    yank two lines, appending to a
--   <C-y>$ +    yank to end of line into the clipboard
--
-- The register key is the last key. Esc cancels. Uppercase appends.
--
-- To use `gy` instead of <C-y>, change YANK_LHS below. Nothing else needs to
-- change; `gy` has no built-in meaning in normal mode.
--
-- Note: <C-y> natively scrolls the window up one line. If you rely on that,
-- switch to `gy`.
--
-- Custom operators cannot be repeated with `.`; that is a Vim limitation for
-- g@-based operators.

local M = {}

local YANK_LHS = "<C-y>"

local regtype = {
	char = "v",
	line = "V",
	block = "\22",
}

-- Called by the g@ operator once the motion is complete. The register key is
-- read here, so the full sequence is <C-y>{motion}{register}.
function M.operator(rtype)
	local reg = vim.fn.getcharstr()
	if reg == "" or reg == "\27" then
		return
	end

	local start = vim.fn.getpos("'[")
	local finish = vim.fn.getpos("']")
	local rtype = regtype[rtype] or "v"

	local ok, text = pcall(vim.fn.getregion, start, finish, { type = rtype })
	if not ok then
		return
	end

	pcall(vim.fn.setreg, reg, text, rtype)
end

function M.setup()
	vim.o.operatorfunc = "v:lua.require'az.yank'.operator"

	vim.keymap.set("n", YANK_LHS, "g@", {
		desc = "Yank motion into a register (register after motion)",
	})

	-- Make <C-y>y (and count<C-y>y) linewise. `y` is not a valid motion for
	-- any other operator, so native `y`, `yy`, `dd`, `cc`, etc. are unaffected.
	vim.keymap.set("o", "y", function()
		return vim.v.operator == "g@" and "_" or "y"
	end, {
		expr = true,
		replace_keycodes = false,
		desc = "Linewise yank for the register-after-motion operator",
	})
end

return M
