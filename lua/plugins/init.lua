-- Loader: `packadd!` every plugin directory under pack/nvim/opt/, then
-- require its setup module. Each setup module is wrapped in pcall so a
-- missing/broken submodule will not break the whole config.

local M = {}

local function packadd_all_opt()
  local config = vim.fn.stdpath('config')
  local opt_dir = config .. '/pack/nvim/opt'
  if vim.fn.isdirectory(opt_dir) == 0 then return end
  for _, path in ipairs(vim.fn.glob(opt_dir .. '/*', true, true)) do
    if vim.fn.isdirectory(path) == 1 then
      local name = vim.fn.fnamemodify(path, ':t')
      pcall(vim.cmd, 'packadd! ' .. name)
    end
  end
end

-- Order matters: deps and theming first, then features.
local setup_modules = {
  'plugins.colorscheme',
  'plugins.treesitter',
  'plugins.lsp',
  'plugins.cmp',
  'plugins.telescope',
  'plugins.lualine',
  'plugins.gitsigns',
  'plugins.nvimtree',
  'plugins.whichkey',
  'plugins.autopairs',
}

function M.setup()
  packadd_all_opt()
  for _, mod in ipairs(setup_modules) do
    local ok, err = pcall(require, mod)
    if not ok then
      vim.notify(('[plugins] %s: %s'):format(mod, err), vim.log.levels.WARN)
    end
  end
end

M.setup()
return M
