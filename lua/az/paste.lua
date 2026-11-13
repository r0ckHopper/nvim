-- Paste-first register mappings.
--
--   pp = p        pa = "ap       pA = "ap       p+ = "+p
--   PP = P        Pa = "aP       PA = "aP       P+ = "+P
--   gpp = gp      gpa = "agp     gpA = "agp
--   gPp = gP      gPa = "agP     gPA = "agP
--
-- The first key chooses after/before (and cursor placement for the g forms).
-- The second key chooses the register. Second-key p/P always means the
-- unnamed register, and uppercase letters are folded to lowercase, so holding
-- shift on the second key (or on the first) cannot change which register is
-- read.
--
-- Counts carry through automatically, e.g. 3pa -> 3"ap.

local M = {}

-- Second key -> register name. A nil register means the unnamed register.
local second = {}

for c in ("0123456789"):gmatch(".") do
	second[#second + 1] = { key = c, reg = c }
end

for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
	if c ~= "p" then
		second[#second + 1] = { key = c, reg = c }
	end
end

for c in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do
	if c ~= "P" then
		second[#second + 1] = { key = c, reg = c:lower() }
	end
end

for _, c in ipairs({ '"', '-', ':', '.', '%', '#', '=', '*', '+', '_', '/' }) do
	second[#second + 1] = { key = c, reg = c }
end

second[#second + 1] = { key = "p", reg = nil }
second[#second + 1] = { key = "P", reg = nil }

local prefixes = {
	{ modes = { "n", "x" }, lhs = "p", rhs = "p", where = "after" },
	{ modes = { "n", "x" }, lhs = "P", rhs = "P", where = "before" },
	{ modes = { "n" }, lhs = "gp", rhs = "gp", where = "after, cursor after" },
	{ modes = { "n" }, lhs = "gP", rhs = "gP", where = "before, cursor after" },
}

function M.setup()
	vim.o.timeout = true

	for _, prefix in ipairs(prefixes) do
		for _, s in ipairs(second) do
			local rhs = s.reg and ('"' .. s.reg .. prefix.rhs) or prefix.rhs
			local what = s.reg and ("register " .. s.reg) or "unnamed register"
			vim.keymap.set(prefix.modes, prefix.lhs .. s.key, rhs, {
				desc = "paste " .. prefix.where .. " from " .. what,
			})
		end
	end
end

return M
