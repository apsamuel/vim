-- nvim-only keymaps (shared maps live in `vimrc`).
local map = vim.keymap.set

-- Diagnostics
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Prev diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Line diagnostics' })
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics → loclist' })

-- Quick source of init.lua during config dev
map('n', '<leader>vs', '<cmd>source $MYVIMRC<CR>', { desc = 'Source init.lua' })

-- Terminal-mode escape
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Term: leave insert' })
