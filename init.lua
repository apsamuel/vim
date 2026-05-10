-- =============================================================================
-- init.lua — Neovim entrypoint
-- 1. Source the shared `vimrc` (options, keymaps, classic-plugin guards).
-- 2. Load nvim-only core modules (options, keymaps, autocmds).
-- 3. `packadd!` every plugin under pack/nvim/opt/ and require its setup.
-- =============================================================================

-- Resolve config dir (works whether ~/.config/nvim is the dir or a symlink).
local config_dir = vim.fn.stdpath('config')

-- 1. Shared vimrc
local vimrc = config_dir .. '/vimrc'
if vim.fn.filereadable(vimrc) == 1 then
  vim.cmd('source ' .. vim.fn.fnameescape(vimrc))
end

-- 2. nvim-only core
local function safe_require(mod)
  local ok, err = pcall(require, mod)
  if not ok then
    vim.notify(('[init] failed to load %s: %s'):format(mod, err), vim.log.levels.WARN)
  end
end

safe_require('core.options')
safe_require('core.keymaps')
safe_require('core.autocmds')

-- 3. Plugins (packadd! + setup). Wrapped so a missing submodule does not
--    bring the whole config down.
safe_require('plugins')
