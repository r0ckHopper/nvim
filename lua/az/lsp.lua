--lua config
vim.lsp.config('luals', {
	cmd = { 'lua-language-server' },
	filetypes = { 'lua' },
	root_markers = { '.luarc.json', '.luarc.jsonc', '.git', 'init.lua' },
	settings = {
		Lua = {
			runtime = { version = 'LuaJIT' },
			diagnostics = { globals = { 'vim' } },
			workspace = {
				library = vim.api.nvim_get_runtime_file('', true),
			},
			telemetry = { enable = false },
		},
	},
})

vim.lsp.enable('luals')

--zls config
vim.lsp.config['zls'] = {
	-- Set to 'zls' if `zls` is in your PATH
	cmd = { '/usr/local/bin/zls' },
	filetypes = { 'zig' },
	root_markers = { 'build.zig' },
	-- There are two ways to set config options:
	--   - edit your `zls.json` that applies to any editor that uses ZLS
	--   - set in-editor config options with the `settings` field below.
	--
	-- Further information on how to configure ZLS:
	-- https://zigtools.org/zls/configure/
	settings = {
		zls = {
			-- Whether to enable build-on-save diagnostics
			--
			-- Further information about build-on save:
			-- https://zigtools.org/zls/guides/build-on-save/
			-- enable_build_on_save = true,

			-- omit the following line if `zig` is in your PATH
			enable_build_on_save = true,
			build_on_save_args = { "-fincremental" },
			zig_exe_path = '/usr/bin/zig'
		}
	},
}
vim.lsp.enable('zls')

-- clangd config for C++
vim.lsp.config('clangd', {
	cmd = { 'clangd' },
	filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
	root_markers = { 
		'.clangd', 
		'compile_commands.json', 
		'compile_flags.txt',
		'CMakeLists.txt',
		'Makefile'
	},
})
vim.lsp.enable('clangd')

-- [EXPERIMENTAL] bgfx shader analyzer — forked from glsl_analyzer
-- Provides completion, hover, goto-def for bgfx .sc/.sh shader files.
-- Expect false positives on bgfx-specific macros; platform-conditional
-- code (#ifdef BGFX_SHADER_LANGUAGE_HLSL) is not analyzed.
-- Repo: /home/akhursheed/source/shader_lsp/bgfx_shader_analyzer
vim.lsp.config('bgfx_shader_analyzer', {
	cmd = { 'bgfx_shader_analyzer' },
	filetypes = { 'sc', 'sh', 'glsl', 'vert', 'frag', 'comp', 'geom', 'tesc', 'tese' },
	root_markers = { '.git', 'varying.def.sc' },
})
vim.lsp.enable('bgfx_shader_analyzer')

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
	pattern = '*.sc',
	callback = function()
		vim.bo.filetype = 'sc'
	end,
})

-- typescript
vim.lsp.config('tsserver', {
	cmd = {'typescript-language-server', '--stdio'},
	filetypes = { 'typescript' },
	root_dir = vim.fs.root(0, {'package.json', '.git'}),
	on_attach = on_attach,
	capabilities = capabilities,
})
vim.lsp.enable('tsserver')




-- C# 
vim.pack.add({'https://github.com/seblyng/roslyn.nvim'})
require('roslyn').setup({
	broad_search = true,
	settings = {
		["omnisharp|background_build"] = true,  -- needed for generated files
	}
})
--vim.lsp.config("roslyn", {
--  settings = {
--    ["csharp|inlay_hints"] = {
--      csharp_enable_inlay_hints_for_implicit_variable_types = true,
--    },
--  },
--})

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
	pattern = '*.cs',
	callback = function()
		vim.bo.filetype = 'cs'
	end,
})
