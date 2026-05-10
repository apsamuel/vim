local ok, gs = pcall(require, 'gitsigns')
if not ok then return end

gs.setup({
  signs = {
    add          = { text = '│' },
    change       = { text = '│' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
  },
  on_attach = function(bufnr)
    local g = require('gitsigns')
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
    end
    map('n', ']h', function() g.nav_hunk('next') end, 'Next hunk')
    map('n', '[h', function() g.nav_hunk('prev') end, 'Prev hunk')
    map('n', '<leader>hs', g.stage_hunk,    'Stage hunk')
    map('n', '<leader>hr', g.reset_hunk,    'Reset hunk')
    map('n', '<leader>hp', g.preview_hunk,  'Preview hunk')
    map('n', '<leader>hb', function() g.blame_line({ full = true }) end, 'Blame line')
  end,
})
