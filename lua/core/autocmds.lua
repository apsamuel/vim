-- nvim-only autocmds.
local au = vim.api.nvim_create_autocmd
local group = vim.api.nvim_create_augroup('user_autocmds', { clear = true })

-- Highlight yanked text briefly.
au('TextYankPost', {
  group = group,
  callback = function() vim.highlight.on_yank({ timeout = 150 }) end,
})

-- Resize splits when the host window changes.
au('VimResized', {
  group = group,
  command = 'tabdo wincmd =',
})

-- Close some buffers with `q`.
au('FileType', {
  group = group,
  pattern = { 'help', 'qf', 'man', 'lspinfo', 'checkhealth', 'startuptime' },
  callback = function(args)
    vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = args.buf, silent = true })
  end,
})
