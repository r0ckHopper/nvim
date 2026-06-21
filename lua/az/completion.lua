vim.pack.add({
	"https://github.com/Saghen/blink.lib",
	"https://github.com/Saghen/blink.cmp",
	"https://github.com/L3MON4D3/LuaSnip",
	"https://github.com/rafamadriz/friendly-snippets"
})
-- for native completions but we are using blink instead
--vim.api.nvim_create_autocmd('LspAttach', {
--	group = vim.api.nvim_create_augroup('my.lsp', {}),
--	callback = function(ev)
--		local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
--
--		-- Enable auto-completion. Note: Use CTRL-Y to select an item. |complete_CTRL-Y|
--		if client:supports_method('textDocument/completion') then
--			-- Optional: trigger autocompletion on EVERY keypress. May be slow!
--			-- local chars = {}; for i = 32, 126 do table.insert(chars, string.char(i)) end
--			-- client.server_capabilities.completionProvider.triggerCharacters = chars
--			vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
--		end
--	end,
--})
--vim.cmd("set completeopt+=noselect")
require("luasnip.loaders.from_vscode").lazy_load()
require("blink.cmp").setup({
	--dependencies = { 'rafamadriz/friendly-snippets' },
	keymap = {
		preset = 'enter',
		["<Tab>"] = { "select_next", "fallback" },
		["<S-Tab>"] = { "select_prev", "fallback" },
		["<C-l>"] = { "snippet_forward", "fallback" },
		["<C-h>"] = { "snippet_backward", "fallback" },
	},

	appearance = {
		nerd_font_variant = 'mono'
	},
	completion = {
		documentation = { auto_show = true, auto_show_delay_ms = 500},
		menu = {
			auto_show = true,
			draw = {
				treesitter = { "lsp" },
				columns = {{"kind_icon", "label", "label_description", gap = 1 }, { "kind" } },
			},
		},
		list = {
			selection = {
				preselect = false,
			},
		},
	},
	sources = {
		default = { 'lsp', 'path', 'snippets', 'buffer' },
	},
	fuzzy = {
		implementation = "lua",
		sorts = { "score", "kind", "label" }, --temp for bgfx lsp testing
	},
	signature = {enabled = true },
})

--highlights
local function set_colors()
		vim.api.nvim_set_hl(0, 'Pmenu', {
		bg = 'NONE',
	})
		vim.api.nvim_set_hl(0, 'BlinkCmpKindSnippet', {
		fg = '#ffff00',
	})
end
set_colors()
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = set_colors,
})
