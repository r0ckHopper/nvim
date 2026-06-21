vim.pack.add({
"https://github.com/ThePrimeagen/git-worktree.nvim",
})
require("git-worktree").setup()
require("telescope").load_extension("git_worktree")

vim.keymap.set('n', '<leader>fw', function() require('telescope').extensions.git_worktree.git_worktrees() end, { desc = 'Telescope worktree' })
