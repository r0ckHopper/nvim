
local function set_dap_highlights()
	vim.api.nvim_set_hl(0, 'DapBreakpoint', { link = 'Exception' })
	vim.api.nvim_set_hl(0, 'DapBreakpointCondition', { fg = '#ffff00', ctermfg = 'Yellow' })
	vim.api.nvim_set_hl(0, 'DapBreakpointRejected', { fg = '#0066ff', ctermfg = 'Blue' })
	vim.api.nvim_set_hl(0, 'DapLogPoint', { fg = '#cc00ff', ctermfg = 'Magenta' })
	vim.api.nvim_set_hl(0, 'DapStopped', { fg = '#33ff00', ctermfg = 'Green' })
	vim.api.nvim_set_hl(0, 'debugPC', { bg = '#333333', fg = '#ff0000' })

	-- Redefine DAP signs to use correct highlight groups instead of SignColumn
	vim.fn.sign_define('DapBreakpoint', { text = "B", texthl = 'DapBreakpoint', linehl = '', numhl = '' })
	vim.fn.sign_define('DapBreakpointCondition', { text = "C", texthl = 'DapBreakpointCondition', linehl = '', numhl = '' })
	vim.fn.sign_define('DapBreakpointRejected', { text = 'R', texthl = 'DapBreakpointRejected', linehl = '', numhl = '' })
	vim.fn.sign_define('DapLogPoint', { text = 'L', texthl = 'DapLogPoint', linehl = '', numhl = '' })
	vim.fn.sign_define('DapStopped', { text = '→', texthl = 'DapStopped', linehl = 'debugPC', numhl = '' })

	vim.api.nvim_set_hl(0, 'DapUIBreakpointsLine', { link = 'DapBreakpoint' })
	vim.api.nvim_set_hl(0, 'DapUIBreakpointsCurrentLine', { link = 'DapBreakpointCondition' })
	vim.api.nvim_set_hl(0, 'DapUIBreakpointsDisabledLine', { link = 'Comment' })
	vim.api.nvim_set_hl(0, 'DapUIBreakpointsPath', { link = 'Identifier' })
	vim.api.nvim_set_hl(0, 'DapUIBreakpointsInfo', { link = 'Statement' })
	vim.api.nvim_set_hl(0, 'DapUIVariable', { link = 'Normal' })
	vim.api.nvim_set_hl(0, 'DapUIScope', { link = 'Identifier' })
	vim.api.nvim_set_hl(0, 'DapUIType', { link = 'Type' })
	vim.api.nvim_set_hl(0, 'DapUIValue', { link = 'Normal' })
	vim.api.nvim_set_hl(0, 'DapUIModifiedValue', { link = 'Function' })
	vim.api.nvim_set_hl(0, 'DapUIDecoration', { link = 'Identifier' })
	vim.api.nvim_set_hl(0, 'DapUIThread', { link = 'Identifier' })
	vim.api.nvim_set_hl(0, 'DapUIStoppedThread', { link = 'Function' })
	vim.api.nvim_set_hl(0, 'DapUIFrameName', { link = 'Normal' })
	vim.api.nvim_set_hl(0, 'DapUISource', { link = 'Define' })
	vim.api.nvim_set_hl(0, 'DapUILineNumber', { link = 'LineNr' })
	vim.api.nvim_set_hl(0, 'DapUICurrentFrameName', { link = 'DapUIBreakpointsCurrentLine' })
	vim.api.nvim_set_hl(0, 'DapUIStepOver', { link = 'Label' })
	vim.api.nvim_set_hl(0, 'DapUIStepInto', { link = 'Label' })
	vim.api.nvim_set_hl(0, 'DapUIStepBack', { link = 'Label' })
	vim.api.nvim_set_hl(0, 'DapUIStepOut', { link = 'Label' })
	vim.api.nvim_set_hl(0, 'DapUIStop', { link = 'PreProc' })
	vim.api.nvim_set_hl(0, 'DapUIPlayPause', { link = 'Repeat' })
	vim.api.nvim_set_hl(0, 'DapUIRestart', { link = 'Repeat' })
	vim.api.nvim_set_hl(0, 'DapUIUnavailable', { link = 'Comment' })
	vim.api.nvim_set_hl(0, 'DapUIWinSelect', { link = 'Special' })
	vim.api.nvim_set_hl(0, 'DapUIEndofBuffer', { link = 'EndofBuffer' })
	vim.api.nvim_set_hl(0, 'DapUIFloatNormal', { link = 'NormalFloat' })
	vim.api.nvim_set_hl(0, 'DapUIFloatBorder', { link = 'Identifier' })
	vim.api.nvim_set_hl(0, 'DapUIWatchesEmpty', { link = 'PreProc' })
	vim.api.nvim_set_hl(0, 'DapUIWatchesValue', { link = 'Statement' })
	vim.api.nvim_set_hl(0, 'DapUIWatchesError', { link = 'PreProc' })
--NvimDapVirtualText xxx links to Comment
--NvimDapVirtualTextChanged xxx links to DiagnosticVirtualTextWarn
--NvimDapVirtualTextError xxx links to DiagnosticVirtualTextError
--NvimDapVirtualTextInfo xxx links to DiagnosticVirtualTextInfo
	vim.api.nvim_set_hl(0, 'NvimDapVirtualText', { fg = '#00ffff', bg = '#000000', altfont = true, italic = true, bold = true})
	vim.api.nvim_set_hl(0, 'NvimDapVirtualTextChanged', { fg = '#f09000', bg = '#000000' , altfont = true, italic = true, bold = true})
	vim.api.nvim_set_hl(0, 'NvimDapVirtualTextError', { fg = '#00ffff', bg = '#000000', altfont = true, italic = true, bold = true})
	vim.api.nvim_set_hl(0, 'NvimDapVirtualTextInfo', { fg = '#00ffff', bg = '#000000', altfont = true, italic = true, bold = true})
end

set_dap_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
	callback = set_dap_highlights,
})
