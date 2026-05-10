-- LSP: mason installs servers on demand; nvim-lspconfig 3.x ships only the
-- per-server config tables which we feed to vim.lsp.config / vim.lsp.enable
-- (nvim 0.11+ API).
local ok_mason, mason = pcall(require, 'mason')
if ok_mason then
  mason.setup({ ui = { border = 'rounded' } })
end

local ok_mlsp, mlsp = pcall(require, 'mason-lspconfig')

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
  map('n', '<leader>fF', function() vim.lsp.buf.format({ async = true }) end, 'LSP format')
end

-- LspAttach autocmd applies on_attach to any client (works whether the server
-- is launched via vim.lsp.config or fallback nvim-lspconfig.setup_handlers).
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then on_attach(client, args.buf) end
  end,
})

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

-- nvim 0.11+: configure & enable each server via the new API. nvim-lspconfig
-- ships configs under lsp/<name>.lua which vim.lsp.config picks up; our
-- overrides are merged on top.
local has_new_api = vim.lsp and vim.lsp.config and vim.lsp.enable
if has_new_api then
  for _, name in ipairs(servers) do
    local opts = vim.tbl_deep_extend('force',
      { capabilities = capabilities },
      server_opts[name] or {})
    pcall(vim.lsp.config, name, opts)
  end
  pcall(vim.lsp.enable, servers)
else
  -- Fallback for nvim < 0.11 with old lspconfig.
  local ok_lspc, lspconfig = pcall(require, 'lspconfig')
  if ok_lspc then
    for _, name in ipairs(servers) do
      local opts = vim.tbl_deep_extend('force',
        { capabilities = capabilities, on_attach = on_attach },
        server_opts[name] or {})
      pcall(function() lspconfig[name].setup(opts) end)
    end
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
