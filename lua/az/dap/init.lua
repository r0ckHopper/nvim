require('az.dap.dap')
require('az.dap.dap-highlights')
require('az.dap.dotnet')

-- Apply dapui config LAST so dotnet-debug doesn't override it
require("dapui").setup({
	layouts = {
		{
			elements = {
				{ id = "repl", size = 0.7 },
				{ id = "watches", size = 0.3 },
			},
			size = 55,
			position = "right",
		},
	},
})
