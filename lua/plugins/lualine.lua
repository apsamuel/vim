local ok, lualine = pcall(require, 'lualine')
if not ok then return end

lualine.setup({
  options = {
    icons_enabled = true,
    theme = 'auto',
    globalstatus = true,
    section_separators = { left = '', right = '' },
    component_separators = { left = '│', right = '│' },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff', { 'diagnostics', sources = { 'nvim_diagnostic' } } },
    lualine_c = { { 'filename', path = 1 } },
    lualine_x = { 'encoding', 'fileformat', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
  extensions = { 'nvim-tree', 'fugitive', 'quickfix' },
})
