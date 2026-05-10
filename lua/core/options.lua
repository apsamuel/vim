-- nvim-only option overrides (most options come from shared `vimrc`).
local opt = vim.opt

opt.completeopt = { 'menu', 'menuone', 'noselect' }
opt.pumheight = 12
opt.shortmess:append('c')
-- Each fillchar must be exactly one display cell. Glyphs from a Nerd Font
-- work; if you don't have one, use simple ASCII (e.g. '-', '|').
opt.fillchars = { eob = ' ', fold = ' ', foldopen = 'v', foldsep = '|', foldclose = '>' }

-- treesitter handles folds where available
opt.foldmethod = 'expr'
opt.foldexpr = 'nvim_treesitter#foldexpr()'
opt.foldenable = false   -- start unfolded
opt.foldlevel = 99

-- inccommand preview for :s
opt.inccommand = 'split'
