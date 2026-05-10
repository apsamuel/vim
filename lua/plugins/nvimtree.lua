local ok, tree = pcall(require, 'nvim-tree')
if not ok then return end

-- recommended: disable netrw at startup
vim.g.loaded_netrw       = 1
vim.g.loaded_netrwPlugin = 1

tree.setup({
  view   = { width = 36, side = 'left', preserve_window_proportions = true },
  filters = { dotfiles = false, custom = { '^\\.git$', '__pycache__' } },
  renderer = {
    highlight_git = true,
    indent_markers = { enable = true },
    icons = { show = { git = true, folder = true, file = true, folder_arrow = true } },
  },
  git = { enable = true, ignore = false },
  actions = { open_file = { quit_on_open = false } },
})

local map = vim.keymap.set
map('n', '<leader>nt', '<cmd>NvimTreeToggle<CR>', { desc = 'File tree toggle' })
map('n', '<leader>nf', '<cmd>NvimTreeFindFile<CR>', { desc = 'Reveal file' })
