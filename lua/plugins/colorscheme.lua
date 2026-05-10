-- Pick a colorscheme. Tries the modern Lua themes first, then falls back
-- to gruvbox (vimscript) which is also vendored under pack/shared/start.
local function try(name)
  local ok = pcall(vim.cmd.colorscheme, name)
  return ok
end

-- Configure catppuccin / tokyonight if present.
pcall(function()
  require('catppuccin').setup({
    flavour = 'mocha',
    integrations = {
      treesitter = true,
      telescope = { enabled = true },
      gitsigns = true,
      nvimtree = true,
      cmp = true,
      mason = true,
      which_key = true,
    },
  })
end)

pcall(function()
  require('tokyonight').setup({ style = 'storm' })
end)

-- Order of preference:
if not try('gruvbox') then
  if not try('catppuccin') then
    if not try('tokyonight') then
      try('habamax')
    end
  end
end
