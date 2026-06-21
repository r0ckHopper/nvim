local M = {}

-- Build commands for .NET MAUI Android

-- Returns the AdbTarget MSBuild property, properly quoted for the shell.
-- Uses single quotes so bash passes it as one argument to dotnet.
local function adb_flag()
	if vim.g.adb_serial then
		return "'-p:AdbTarget=-s " .. vim.g.adb_serial .. "'"
	end
	return ""
end

local function dotnet_build()
	vim.cmd("FloatermNew --position=bottomright --width=0.5 --height=0.3 dotnet build -f net10.0-android -p:Configuration=Debug " .. adb_flag())
	vim.schedule(function()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true),
			"n",
			false
		)
	end)
end

local function dotnet_run()
	vim.cmd("FloatermNew --position=bottomright --width=0.5 --height=0.3 dotnet build -t:Run -f net10.0-android -p:Configuration=Debug"
		.. " -p:AndroidAttachDebugger=true -p:AndroidSdbTargetPort=50703 -p:AndroidSdbHostPort=50703 "
		.. adb_flag())
	vim.schedule(function()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true),
			"n",
			false
		)
	end)
end

local function dotnet_clean()
	vim.cmd("FloatermNew --position=bottomright --width=0.5 --height=0.3 dotnet clean -f net10.0-android -p:Configuration=Debug " .. adb_flag())
	vim.schedule(function()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true),
			"n",
			false
		)
	end)
end

local function dotnet_select_device()
	local handle = io.popen("adb devices | tail -n +2 | grep 'device$'")
	local result = handle:read("*a")
	handle:close()

	local devices = {}
	for line in result:gmatch("[^\n]+") do
		local serial = line:match("([%w%.%-_]+)")
		if serial then
			table.insert(devices, serial)
		end
	end

	if #devices == 0 then
		vim.notify("No Android devices found", vim.log.levels.WARN)
		return
	end

	vim.ui.select(devices, {
		prompt = "Select Android device:",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice then
			vim.g.adb_serial = choice     -- just the serial (no "-s " prefix)
			vim.g.adb_target = "-s " .. choice  -- kept for plugin compat
			vim.notify("Android device: " .. choice, vim.log.levels.INFO)
		end
	end)
end

-- Check if current directory is a .NET project by searching for .csproj files
local function is_dotnet_project()
	local bufnr = vim.api.nvim_get_current_buf()
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		return false
	end
	local dir = vim.fn.fnamemodify(filepath, ':h')

	local max_depth = 5
	for depth = 0, max_depth do
		local csproj_files = vim.fn.glob(dir .. '/*.csproj')
		if csproj_files ~= "" then
			return true
		end

		local parent = vim.fn.fnamemodify(dir, ':h')
		if parent == dir then
			break
		end
		dir = parent
	end

	return false
end

-- Setup .NET build commands for current buffer
function M.setup_buffer()
	if not is_dotnet_project() then
		return
	end

	vim.keymap.set("n", "<leader>nb", dotnet_build, { buffer = true, desc = ".NET: Build" })
	vim.keymap.set("n", "<leader>nr", dotnet_run, { buffer = true, desc = ".NET: Build + Deploy + Run" })
	vim.keymap.set("n", "<leader>nc", dotnet_clean, { buffer = true, desc = ".NET: Clean" })
	vim.keymap.set("n", "<leader>ns", dotnet_select_device, { buffer = true, desc = ".NET: Select Android device" })
end

-- Setup autocmd to detect .NET projects
function M.setup()
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function(args)
			if is_dotnet_project() then
				M.setup_buffer()
			end
		end,
	})
end

return M
