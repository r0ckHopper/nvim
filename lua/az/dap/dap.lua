vim.pack.add({
	"https://github.com/mfussenegger/nvim-dap",
	"https://github.com/nvim-neotest/nvim-nio",
	"https://github.com/rcarriga/nvim-dap-ui",
	"https://github.com/theHamsta/nvim-dap-virtual-text",
	"https://github.com/nvim-telescope/telescope-dap.nvim",
})


require("nvim-dap-virtual-text").setup({})

require("telescope").load_extension("dap")

local dap = require('dap')
-- Breakpoints
vim.keymap.set('n', '<leader>xB', function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, { desc = 'Breakpoint Condition' })
vim.keymap.set('n', '<leader>xb', function() dap.toggle_breakpoint() end, { desc = 'Toggle Breakpoint' })
-- Debug control
vim.keymap.set('n', '<leader>xc', function() dap.continue() end, { desc = 'Run/Continue' })
vim.keymap.set('n', '<F5>', function() dap.continue() end, { desc = 'Run/Continue' })
vim.keymap.set('n', '<leader>xC', function() dap.run_to_cursor() end, { desc = 'Run to Cursor' })
vim.keymap.set('n', '<leader>xg', function() dap.goto_() end, { desc = 'Go to Line (No Execute)' })
vim.keymap.set('n', '<leader>xl', function() dap.run_last() end, { desc = 'Run Last' })
vim.keymap.set('n', '<leader>xP', function() dap.pause() end, { desc = 'Pause' })
vim.keymap.set('n', '<leader>xt', function() dap.terminate() end, { desc = 'Terminate' })
-- Stepping
vim.keymap.set('n', '<F11>', function() dap.step_into() end, { desc = 'Step Into' })
vim.keymap.set('n', '<leader>xi', function() dap.step_into() end, { desc = 'Step Into' })
vim.keymap.set('n', '<F12>', function() dap.step_out() end, { desc = 'Step Out' })
vim.keymap.set('n', '<leader>xo', function() dap.step_out() end, { desc = 'Step Out' })
vim.keymap.set('n', '<F10>', function() dap.step_over() end, { desc = 'Step Over' })
vim.keymap.set('n', '<leader>xO', function() dap.step_over() end, { desc = 'Step Over' })
-- Stack navigation
vim.keymap.set('n', '<leader>xj', function() dap.down() end, { desc = 'Down' })
vim.keymap.set('n', '<leader>xk', function() dap.up() end, { desc = 'Up' })
-- Session/REPL
vim.keymap.set('n', '<leader>xr', function() dap.repl.toggle() end, { desc = 'Toggle REPL' })
vim.keymap.set('n', '<leader>xs', function() dap.session() end, { desc = 'Session' })
-- Widgets
--do
--	local next_row = math.floor(vim.o.lines * 0.1)
--
--	vim.keymap.set('n', '<leader>xw', function()
--		local view = require('dap.ui.widgets').hover()
--		if view and view.win then
--			local config = vim.api.nvim_win_get_config(view.win)
--			local height = config.height or 10
--			vim.api.nvim_win_set_config(view.win, {
--				relative = 'editor',
--				row = next_row,
--				col = math.floor(vim.o.columns * 0.6),
--			})
--			next_row = next_row + height + 1
--
--			-- Reset if no more dap float windows are visible
--			vim.defer_fn(function()
--				local any_open = false
--				for _, win in ipairs(vim.api.nvim_list_wins()) do
--					if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dap-float" then
--						any_open = true
--						break
--					end
--				end
--				if not any_open then
--					next_row = math.floor(vim.o.lines * 0.1)
--				end
--			end, 100)
--		end
--	end, { desc = 'Hover (right float)' })
--end

-- dapui controls
vim.keymap.set('n', '<leader>xu', function() require('dapui').toggle() end, { desc = 'Dap UI' })
vim.keymap.set({'n', 'x'}, '<leader>xe', function() require('dapui').eval() end, { desc = 'Eval' })
vim.keymap.set('n', '<leader>xf', function() require('dapui').float_element('scopes') end, { desc = 'Float Scopes' })
vim.keymap.set('n', '<leader>xh', function() require('dapui').toggle('hover') end, { desc = 'Toggle Hover' })
vim.keymap.set({'n', 'v'}, '<leader>xw', function() require('dapui').elements.watches.add() end, { desc = 'Add to Watches' })

-- lldb-dap adapter configuration (commented out, kept for future use)
dap.adapters.lldb = {
	type = 'executable',
	command = '/usr/bin/lldb-dap',
	name = 'lldb'
}

-- gdb-dap adapter configuration
--dap.adapters.gdb = {
--  type = 'executable',
--  command = 'gdb',
--  args = { '--interpreter=dap', '--eval-command', 'set print pretty on' }
--}

-- Zig configuration (applies to any file in a Zig project)
local zig_config = {
	{
		name = 'Launch Zig Project',
		type = 'lldb',
		request = 'launch',
		program = function()
			local cwd = vim.fn.getcwd()
			local project_name = vim.fn.fnamemodify(cwd, ':t')
			local exe_path = cwd .. '/zig-out/bin/' .. project_name

			if vim.fn.executable(exe_path) == 0 then
				print('Warning: Executable not found at ' .. exe_path)
				print('Please build first: zig build -Doptimize=Debug')
			end
			return exe_path
		end,
		cwd = '${workspaceFolder}',
		stopOnEntry = false,
		args = {},
	},
}
local dotnet_config = {
	{
		type = "coreclr",
		name = "Launch .NET Project",
		request = "launch",
		program = function()
			return vim.fn.input("Path to DLL: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
		end,
		cwd = "${workspaceFolder}",
	},
	{
		type = "monovsdbg",
		name = "Launch MAUI Android (build + debug)",
		request = "launch",
		projectPath = "${workspaceFolder}/OpenSSH.csproj",
	},
	{
		type = "mono-attach",
		name = "Attach to MAUI Android (debug only, app must be running)",
		request = "attach",
		address = "localhost",
		port = 50703,
	},
}

-- Adapter that starts mono-debug and attaches to a running MAUI Android app
dap.adapters["mono-attach"] = function(on_config, config)
	local mono_debug_path = vim.fn.expand("~/mono-debug/mono-debug")
	vim.uv.spawn(mono_debug_path, {
		args = { "--server" },
		detached = true,
	}, function() end)

	vim.defer_fn(function()
		on_config({
			id = "mono",
			type = "server",
			port = 4711,
		})
	end, 500)
end

dap.configurations.cs = dotnet_config
dap.configurations.zig = zig_config

vim.api.nvim_create_autocmd("FileType", {
	callback = function()
		local cwd = vim.fn.getcwd()
		if vim.fn.filereadable(cwd .. "/build.zig") == 1 then
			dap.configurations[vim.bo.filetype] = zig_config
		end
	end,
})


