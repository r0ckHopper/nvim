vim.pack.add { "https://github.com/brianhuster/unnest.nvim" }

-- !! LOCAL MODIFICATIONS to plugin/unnest.lua in the pack install:
--   1. No new tab — opens files in current window instead
--   2. Bare `nvim` opens oil.nvim in current dir (fire-and-forget)
--   3. Restores terminal buffer when file is closed (no <C-o> needed)
--   These will be overwritten on plugin update — re-apply after updates.


