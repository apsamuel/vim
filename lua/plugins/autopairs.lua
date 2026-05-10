local ok, ap = pcall(require, 'nvim-autopairs')
if not ok then return end

ap.setup({ check_ts = true })

-- Hook into nvim-cmp confirmation if cmp is loaded.
pcall(function()
  local cmp = require('cmp')
  local cmp_ap = require('nvim-autopairs.completion.cmp')
  cmp.event:on('confirm_done', cmp_ap.on_confirm_done())
end)
