vim.keymap.set("n", "<leader>T",":terminal<CR>")
vim.api.nvim_create_autocmd('TermRequest', {
	pattern = '*',
	callback = function(args)
		local data = args.data
		if not data or not data.sequence then
			return
		end

		local bufnr = args.buf

		if vim.bo[bufnr].filetype == 'floaterm' then
			print('floaterm ')
			return
		end

		local sequence = data.sequence
		-- Check for OSC 7 sequence: ESC]7;file://path
		-- this is being emitted by bash as per .bashrc
		local dir = sequence:match('\27%]7;file://(.+)') or sequence:match('%]7;file://(.+)')

		if dir then
			vim.fn.chdir(dir)
		end
	end
})

