# `.vim` — self-contained vim & neovim configuration

A single repository that:

- works as `~/.vim` for **vim 8+** (auto-loads classic plugins via the native
  package mechanism), and
- works as `~/.config/nvim` for **neovim 0.9+** (additionally bootstraps a
  modern Lua stack — LSP, treesitter, telescope, cmp, gitsigns, …).

Every plugin is a **git submodule** under `pack/<bundle>/{start,opt}/<plugin>`.
A fresh clone with `--recurse-submodules` is a fully-installed config — no
plugin manager, no network access at startup.

## Quick start

```sh
git clone --recurse-submodules https://github.com/<you>/.vim ~/.vim_src
~/.vim_src/install.sh
```

`install.sh` is idempotent. It will:

1. back up any existing `~/.vim`, `~/.vimrc`, `~/.config/nvim` that is not
   already a symlink to this repo,
2. symlink `~/.vim` and `~/.config/nvim` to the repo,
3. `git submodule update --init --recursive --depth 1`,
4. generate vim & nvim helptags,
5. build `telescope-fzf-native` if `make` is available.

Open `nvim` and `mason` will install LSP servers (pyright, gopls, ts_ls,
rust_analyzer, lua_ls, bashls, yamlls, jsonls, taplo, marksman, terraformls,
dockerls) into `~/.local/share/nvim/mason/`.

## Layout

```
.vim/
├── vimrc                shared options/maps/classic-plugin config
├── init.lua             nvim entrypoint (sources vimrc, loads lua/)
├── install.sh           bootstrap (symlinks + submodule init + helptags)
├── Makefile             install / update / add / rm / helptags / doctor
├── lua/
│   ├── core/            options.lua, keymaps.lua, autocmds.lua  (nvim only)
│   └── plugins/         per-plugin setup modules
├── plugin/  after/  ftplugin/  ftdetect/  colors/  snippets/  doc/
└── pack/
    ├── shared/start/    vimscript plugins, both editors
    ├── nvim/opt/        Lua plugins, packadd!'d by nvim only
    └── vim/start/       (reserved for vim-only fallbacks)
```

`pack/shared/start/*` is loaded automatically by **both** vim and nvim.
`pack/nvim/opt/*` is loaded by `lua/plugins/init.lua` via `packadd!`, so vim
never touches the Lua-only plugins.

## Plugin roster

### Shared (vim + nvim) — `pack/shared/start/`

| Plugin                           | Purpose                                                 |
| -------------------------------- | ------------------------------------------------------- |
| tpope/vim-fugitive               | Git porcelain                                           |
| tpope/vim-surround               | Surround text objects                                   |
| tpope/vim-commentary             | `gc` toggles comments                                   |
| tpope/vim-repeat                 | Make `.` work for plugin maps                           |
| tpope/vim-sleuth                 | Auto-detect indent                                      |
| tpope/vim-unimpaired             | `[`/`]` bracket maps                                    |
| tpope/vim-eunuch                 | `:Move`, `:Rename`, `:SudoWrite`                        |
| junegunn/fzf + fzf.vim           | Fuzzy finder (in vim; nvim uses telescope)              |
| editorconfig/editorconfig-vim    | `.editorconfig` support                                 |
| morhetz/gruvbox                  | Primary colorscheme                                     |
| airblade/vim-gitgutter           | Hunk signs (vim only — nvim uses gitsigns)              |
| preservim/nerdtree               | File tree (vim only — nvim uses nvim-tree)              |
| sheerun/vim-polyglot             | Syntax for ~600 langs (vim only — nvim uses treesitter) |
| dense-analysis/ale               | Async lint (vim only — nvim uses LSP diagnostics)       |
| vim-airline/vim-airline + themes | Statusline (vim only — nvim uses lualine)               |

The vim-only plugins are guarded by `if !has('nvim')` blocks in `vimrc`.

### Neovim only — `pack/nvim/opt/`

| Plugin                                                                     | Purpose                       |
| -------------------------------------------------------------------------- | ----------------------------- |
| nvim-lua/plenary.nvim                                                      | Lua stdlib (dependency)       |
| neovim/nvim-lspconfig                                                      | LSP server configs            |
| williamboman/mason.nvim + mason-lspconfig.nvim                             | Install LSP/DAP/lint binaries |
| hrsh7th/nvim-cmp + cmp-nvim-lsp/cmp-buffer/cmp-path                        | Completion                    |
| L3MON4D3/LuaSnip + saadparwaiz1/cmp_luasnip + rafamadriz/friendly-snippets | Snippets                      |
| nvim-treesitter/nvim-treesitter (+ textobjects)                            | Syntax / indent / folds       |
| nvim-telescope/telescope.nvim + telescope-fzf-native.nvim                  | Fuzzy picker                  |
| nvim-lualine/lualine.nvim                                                  | Statusline                    |
| lewis6991/gitsigns.nvim                                                    | Hunk signs / blame            |
| nvim-tree/nvim-tree.lua + nvim-web-devicons                                | File explorer + icons         |
| folke/which-key.nvim                                                       | Key hint popups               |
| windwp/nvim-autopairs                                                      | Auto pair brackets            |
| catppuccin/nvim, folke/tokyonight.nvim                                     | Alternate colorschemes        |

## Daily commands

```sh
make install      # bootstrap (or re-run after pulling a new plugin)
make update       # pull every floated submodule, regenerate helptags
make helptags     # regenerate helptags only
make doctor       # nvim :checkhealth
make list         # list vendored plugins
make clean        # remove the ~/.vim and ~/.config/nvim symlinks
```

## Adding / removing plugins

```sh
# add: BUNDLE=shared (vim+nvim) or BUNDLE=nvim (Lua only)
make add PLUGIN=tpope/vim-rhubarb        BUNDLE=shared
make add PLUGIN=folke/trouble.nvim       BUNDLE=nvim

# remove
make rm  PLUGIN=trouble.nvim BUNDLE=nvim
```

After adding a new shared plugin, restart vim/nvim — `pack/*/start/*` is
auto-loaded. After adding a new nvim plugin, either restart or
`:packadd <name>` and add a setup module under `lua/plugins/`.

## Per-machine overrides

Drop machine-local tweaks in `~/.vimrc.local` — `vimrc` sources it last and
it is never tracked by this repo.

## Use as a submodule of another dotfiles repo

```sh
cd ~/dot
git submodule add git@github.com:<you>/.vim.git .vim
git submodule update --init --recursive
./.vim/install.sh
```

When cloning the parent repo: `git clone --recurse-submodules`.

## Updating plugins

`make update` runs `git submodule update --remote --merge --jobs 8` on every
submodule. To pin a specific plugin to a tag instead of floating on `HEAD`:

```sh
cd pack/nvim/opt/nvim-treesitter
git fetch --tags
git checkout v0.9.2
cd -
git add pack/nvim/opt/nvim-treesitter
git commit -m 'pin nvim-treesitter @ v0.9.2'
```

`make update` will leave that submodule alone unless you bump it manually
(it follows whatever ref the parent records).

## Troubleshooting

- **`E185: Cannot find color scheme 'gruvbox'`** — submodules not initialized.
  Run `git submodule update --init --recursive`.
- **Slow nvim startup** — run `nvim --startuptime /tmp/start.log +qa` and
  inspect.
- **LSP not attaching** — `:LspInfo`. If a server is missing, `:Mason` and
  install it.
- **`telescope-fzf-native` warning** — re-run `make -C pack/nvim/opt/telescope-fzf-native.nvim`.
- **Icons look like boxes** — install a [Nerd Font](https://www.nerdfonts.com/)
  and configure your terminal to use it.
