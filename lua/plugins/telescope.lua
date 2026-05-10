local ok, telescope = pcall(require, 'telescope')
if not ok then return end

local actions = require('telescope.actions')

telescope.setup({
  defaults = {
    prompt_prefix = '  ',
    selection_caret = ' ',
    path_display = { 'truncate' },
    sorting_strategy = 'ascending',
    layout_config = { prompt_position = 'top', horizontal = { preview_width = 0.55 } },
    mappings = {
      i = {
        ['<C-j>'] = actions.move_selection_next,
        ['<C-k>'] = actions.move_selection_previous,
        ['<Esc>'] = actions.close,
      },
    },
  },
  pickers = {
    find_files = { hidden = true, follow = true },
    live_grep  = { additional_args = function() return { '--hidden' } end },
  },
  extensions = {
    fzf = {
      fuzzy = true, override_generic_sorter = true,
      override_file_sorter = true, case_mode = 'smart_case',
    },
  },
})

pcall(telescope.load_extension, 'fzf')

local b = require('telescope.builtin')
local map = vim.keymap.set
map('n', '<leader>ff', b.find_files,  { desc = 'Files' })
map('n', '<leader>fg', b.live_grep,   { desc = 'Grep' })
map('n', '<leader>fb', b.buffers,     { desc = 'Buffers' })
map('n', '<leader>fh', b.help_tags,   { desc = 'Help' })
map('n', '<leader>fr', b.oldfiles,    { desc = 'Recent files' })
map('n', '<leader>fs', b.lsp_document_symbols, { desc = 'Symbols (buf)' })
map('n', '<leader>fS', b.lsp_workspace_symbols, { desc = 'Symbols (ws)' })
map('n', '<leader>fd', b.diagnostics, { desc = 'Diagnostics' })
