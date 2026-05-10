local ok, ts = pcall(require, 'nvim-treesitter.configs')
if not ok then return end

ts.setup({
  ensure_installed = {
    'bash', 'c', 'cpp', 'css', 'dockerfile', 'go', 'gomod', 'gosum',
    'hcl', 'html', 'javascript', 'json', 'jsonc', 'lua', 'luadoc',
    'markdown', 'markdown_inline', 'python', 'query', 'regex', 'rust',
    'terraform', 'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml',
  },
  auto_install = false,   -- we are submodule-vendored; user runs :TSUpdate
  sync_install = false,
  highlight = { enable = true, additional_vim_regex_highlighting = false },
  indent    = { enable = true },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection    = '<C-space>',
      node_incremental  = '<C-space>',
      scope_incremental = '<C-s>',
      node_decremental  = '<C-bs>',
    },
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        ['af'] = '@function.outer', ['if'] = '@function.inner',
        ['ac'] = '@class.outer',    ['ic'] = '@class.inner',
        ['aa'] = '@parameter.outer',['ia'] = '@parameter.inner',
      },
    },
  },
})
