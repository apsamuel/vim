-- LSP: mason installs servers on demand; nvim-lspconfig wires them up.
local ok_mason, mason = pcall(require, 'mason')
if ok_mason then
  mason.setup({ ui = { border = 'rounded' } })
end

local ok_mlsp, mlsp = pcall(require, 'mason-lspconfig')
local ok_lspc, lspconfig = pcall(require, 'lspconfig')
if not ok_lspc then return end

local servers = {
  'pyright', 'gopls', 'ts_ls', 'rust_analyzer', 'lua_ls',
  'bashls', 'yamlls', 'jsonls', 'taplo', 'marksman',
  'terraformls', 'dockerls',
}

if ok_mlsp then
  mlsp.setup({ ensure_installed = servers, automatic_installation = true })
end

-- Capabilities: enrich with cmp-nvim-lsp if loaded.
local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_cmplsp, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
if ok_cmplsp then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

local function on_attach(client, bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
  end
  map('n', 'gd',         vim.lsp.buf.definition,      'LSP definition')
  map('n', 'gD',         vim.lsp.buf.declaration,     'LSP declaration')
  map('n', 'gr',         vim.lsp.buf.references,      'LSP references')
  map('n', 'gi',         vim.lsp.buf.implementation,  'LSP implementation')
  map('n', 'K',          vim.lsp.buf.hover,           'LSP hover')
  map('n', '<C-k>',      vim.lsp.buf.signature_help,  'LSP signature')
  map('n', '<leader>rn', vim.lsp.buf.rename,          'LSP rename')
  map({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, 'LSP code action')
  map('n', '<leader>f',  function() vim.lsp.buf.format({ async = true }) end, 'LSP format')
end

-- Per-server overrides.
local server_opts = {
  lua_ls = {
    settings = {
      Lua = {
        runtime    = { version = 'LuaJIT' },
        diagnostics= { globals = { 'vim' } },
        workspace  = { checkThirdParty = false, library = vim.api.nvim_get_runtime_file('', true) },
        telemetry  = { enable = false },
      },
    },
  },
  gopls = { settings = { gopls = { gofumpt = true, staticcheck = true } } },
}

for _, name in ipairs(servers) do
  local opts = vim.tbl_deep_extend('force',
    { on_attach = on_attach, capabilities = capabilities },
    server_opts[name] or {})
  if lspconfig[name] then
    pcall(function() lspconfig[name].setup(opts) end)
  end
end

-- Diagnostic UI
vim.diagnostic.config({
  virtual_text = { spacing = 2, prefix = '●' },
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  signs = true,
  underline = true,
  update_in_insert = false,
})
