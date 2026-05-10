local ok, wk = pcall(require, 'which-key')
if not ok then return end

wk.setup({ preset = 'modern' })

-- v3 spec: groups are virtual entries that name a leader prefix.
pcall(function()
  wk.add({
    { '<leader>f', group = 'find / format' },
    { '<leader>g', group = 'git' },
    { '<leader>h', group = 'hunk' },
    { '<leader>n', group = 'tree' },
    { '<leader>r', group = 'rename / refactor' },
    { '<leader>c', group = 'code' },
    { '<leader>v', group = 'vim config' },
    { '<leader>b', group = 'buffer' },
  })
end)
