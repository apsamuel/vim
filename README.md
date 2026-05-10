# 📝 `.vim` — a self-contained vim & neovim configuration

> One repository. Two editors. Zero plugin managers. Fully offline after `git clone`.

This repository serves as **both**:

- 🟦 `~/.vim` for **vim 8+**, auto-loading classic plugins through vim's native
  `pack/*/start/*` mechanism, and
- 🟩 `~/.config/nvim` for **neovim 0.9+**, additionally bootstrapping a modern
  Lua stack (LSP via Mason, treesitter, telescope, nvim-cmp, gitsigns, …).

Every plugin is vendored as a **git submodule** under
`pack/<bundle>/{start,opt}/<plugin>`. A fresh clone with
`--recurse-submodules` is a fully-installed configuration — there is no
runtime fetch, no plugin-manager bootstrap step, and no network access
required to start either editor.

---

## ✨ Highlights

- 🧩 **Single source of truth** — one repo, one `vimrc`, one `init.lua`.
- 📦 **Vendored plugins** — every plugin pinned by submodule SHA; reproducible
  and bisectable.
- 🌐 **No plugin manager** — uses vim 8's built-in `:packadd` / `pack/*/start`
  loader. Nothing to bootstrap.
- ✈️ **Offline-friendly** — once submodules are cloned, both editors start
  without any network.
- 🪞 **Vim ↔ nvim parity where it makes sense** — shared options/keymaps;
  modern Lua replacements (LSP, treesitter, telescope, gitsigns, lualine,
  nvim-tree) layered on top under nvim only.
- 🩻 **Helptags pre-generated** — `:help <plugin>` works for everything
  immediately after install.
- 🏠 **Per-machine overrides** — `~/.vimrc.local` is sourced last and is
  never tracked.

---

## 📦 Prerequisites

### ✅ Required

| Tool                               | Why                                                                                      |
| ---------------------------------- | ---------------------------------------------------------------------------------------- |
| `git` ≥ 2.20                       | clone + submodules (with `--depth 1` support)                                            |
| `vim` ≥ 8.0 **or** `nvim` ≥ 0.9    | native package loading (vim) / Lua API (nvim 0.9, 0.11+ ideal)                           |
| `bash` ≥ 4                         | runs `install.sh` and `scripts/plugin-status.sh` (macOS ships 3.2 — `brew install bash`) |
| `make`                             | drives the `Makefile` and per-plugin native builds                                       |
| A C compiler (`cc`/`clang`/`gcc`)  | builds `telescope-fzf-native`, treesitter parsers, optional `jsregexp`                   |
| `cmake` *(or just `make`+`cc`)*    | preferred build path for `telescope-fzf-native` (cleaner)                                |
| Internet access (first clone only) | to fetch submodules and prebuilt `fzf` binary                                            |

### 🧰 Recommended (optional)

| Tool                   | Enables                                                                                |
| ---------------------- | -------------------------------------------------------------------------------------- |
| `node` ≥ 18 + `npm`    | many Mason LSP servers (`ts_ls`, `yamlls`, `jsonls`, `bashls`, `dockerls`, `marksman`) |
| `python3` + `pip`      | `pyright`, `debugpy`                                                                   |
| `go` ≥ 1.21            | `gopls`                                                                                |
| `rustup` / `cargo`     | `rust_analyzer`                                                                        |
| `ripgrep` (`rg`)       | `:Rg` (fzf.vim) and telescope `live_grep`                                              |
| `fd` (`fd-find`)       | faster telescope file finder                                                           |
| `unzip`, `curl`, `tar` | Mason package extraction                                                               |
| A **[Nerd Font]**      | icons in `lualine`, `nvim-tree`, `nvim-web-devicons`                                   |
| A true-color terminal  | enables `termguicolors` + correct theming                                              |

[Nerd Font]: https://www.nerdfonts.com/

> 💡 The config degrades gracefully — missing optional tools just disable the
> features that depend on them; nothing crashes.

---

## 🚀 Quick start

```sh
git clone --recurse-submodules https://github.com/<you>/.vim ~/.vim_src
cd ~/.vim_src
./install.sh
```

That's it. Open `vim` or `nvim` and you're done. See the
[step-by-step walkthrough](#-post-clone-walkthrough) below for what every
step actually does.

---

## 🪜 Post-clone walkthrough

A complete, idempotent setup from a bare machine:

1. **Install prerequisites** — see the [Prerequisites](#-prerequisites) tables.
   At minimum: `git`, `bash`, `make`, a C compiler, and one of vim 8+ / nvim 0.9+.

2. **Clone the repo with submodules.**
   ```sh
   git clone --recurse-submodules https://github.com/<you>/.vim ~/.vim_src
   ```
   The `--recurse-submodules` flag is **important** — without it you'll get an
   empty `pack/` tree and `:colorscheme gruvbox` (and everything else) will
   fail. If you forgot it, run inside the repo:
   ```sh
   git submodule update --init --recursive --depth 1 --jobs 8
   ```

3. **Run the bootstrap installer.**
   ```sh
   cd ~/.vim_src && ./install.sh
   ```
   `install.sh` is **idempotent**. On every invocation it will:
   1. 💾 Back up any existing `~/.vim`, `~/.vimrc`, or `~/.config/nvim` that
      isn't already a symlink to this repo (timestamped `.bak.YYYYMMDD-HHMMSS`).
   2. 🔗 Symlink `~/.vim` and `~/.config/nvim` → this repo.
   3. 📥 Run `git submodule update --init --recursive --depth 1 --jobs 8`.
   4. 🩻 Generate vim and nvim helptags (`:helptags ALL`).
   5. 🛠️  Compile native plugin artifacts via `make build` — see step 4 below
      for the full breakdown.

4. **What `make build` actually compiles.** Three plugins ship source-only
   and need a post-clone build step that `git submodule update` does NOT
   perform. A fourth (treesitter) compiles parsers lazily inside nvim:

   | Artifact                          | Builder                               | Required for                                                                      | Skipped if…                    |
   | --------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------ |
   | `telescope-fzf-native` (`libfzf`) | `cmake` *or* `make` + cc              | telescope's fast fzf-syntax sorter (`require('telescope').load_extension('fzf')`) | neither toolchain present      |
   | `fzf` binary (`bin/fzf`)          | `pack/shared/start/fzf/install --bin` | the `:Files`/`:Rg` commands in fzf.vim                                            | system `fzf` already on `PATH` |
   | `LuaSnip` `jsregexp`              | `make install_jsregexp`               | LSP-snippet *transformations* (`${1/foo/bar/}` style) — optional                  | `make` or `cc` missing         |
   | `nvim-treesitter` parsers         | `:TSUpdateSync`                       | syntax/indent/textobjects per language                                            | nvim or any C compiler missing |

   Run `make plugins` (or `bash scripts/plugin-status.sh`) at any time to see
   which artifacts are still pending — they're listed under a 🧱 *native
   build pending* section.

5. **Launch your editor.**
   - 🟦 `vim` — classic plugins (NERDTree, airline, ALE, fzf.vim, gitgutter,
     polyglot, gruvbox) load automatically.
   - 🟩 `nvim` — the Lua stack initializes; on the first matching filetype
     **Mason** auto-installs LSP servers into
     `~/.local/share/nvim/mason/`. You can also run `:Mason` to manage them
     interactively.

6. **Verify the install.**
   - 🟩 In nvim: `:checkhealth` (or `make doctor`).
   - 🟦 In vim: open any file; verify `:NERDTreeToggle`, `:Files`, `:Git`,
     `:ALEInfo`, and the airline statusline.

7. **(Optional) Add per-machine tweaks.** Drop them in `~/.vimrc.local` —
   sourced last, never tracked.

8. **Stay current.** Run `make update` periodically to refresh floated
   submodules, rebuild native artifacts, and regenerate helptags.

---

## 🧠 Design decisions

### Why no plugin manager?

Vim 8 (2016) shipped native package support: any directory under
`pack/*/start/*` is loaded automatically, and `pack/*/opt/*` is loaded on
demand via `:packadd`. Plugin managers (vim-plug, packer, lazy.nvim)
duplicate this functionality and introduce a runtime fetch step. By skipping
them we get:

- **No bootstrap-of-the-bootstrap.** A bare machine + this repo + submodules
  is a complete configuration.
- **Reproducibility.** Each plugin is pinned to a submodule SHA. Rolling
  back is `git checkout`, not "hope upstream still tags the same release."
- **Offline starts.** No network at editor startup, ever.

### Why git submodules?

Submodules give us per-plugin SHA pinning that lives **in the parent commit**
— git history of this repo *is* the lockfile. `make update` is the only
network step, and it leaves manually-pinned plugins alone.

### Why one repo for both editors?

Most options/keymaps/filetype rules are identical between vim and nvim. The
shared `vimrc` is the lowest common denominator; nvim sources it from
`init.lua` and then layers a modern Lua stack on top. This keeps muscle
memory consistent across hosts that have only `vim` (servers) and hosts
where `nvim` is preferred (workstations).

### Why split `pack/shared/start/` vs `pack/nvim/opt/`?

- **`pack/shared/start/`** auto-loads in **both** editors. Used for vimscript
  plugins that work anywhere (tpope's catalog, fzf.vim, gruvbox,
  editorconfig, …).
- **`pack/nvim/opt/`** is `packadd!`'d **only** by
  `lua/plugins/init.lua`. Vim 8 never touches these directories, so Lua-only
  plugins (treesitter, telescope, mason, …) cannot break the vim path.

This split is the cleanest way to ship one repo that serves both editors
without sprinkling `if has('nvim')` everywhere.

### Why are NERDTree / airline / ALE / gitgutter / polyglot loaded only in vim?

Those plugins are perfectly good but each has a strictly-better Lua-native
replacement under nvim (`nvim-tree`, `lualine`, `nvim-lspconfig`,
`gitsigns`, `nvim-treesitter`). Loading both stacks in nvim wastes startup
time and produces conflicting signs / status segments. The vimrc gates them
behind `if !has('nvim')` so vim users keep the classics and nvim users get
the modern equivalents.

### Why Mason for LSP/DAP binaries?

LSP servers are language toolchains that don't belong in this git repo:
they're large, they're per-architecture, and they update on a different
cadence than this config. Mason installs them into the user's
`~/.local/share/nvim/mason/` so each machine fetches its own. The
`mason-lspconfig` integration with `automatic_installation = true` means
opening a file of a recognized type just works.

### Why no `~/.vimrc` symlink?

Vim 8 auto-discovers `~/.vim/vimrc` as the user vimrc when there's no
`~/.vimrc`. Creating a `~/.vimrc` symlink is therefore redundant; worse,
a stale `~/.vimrc` from another setup would *override* our config silently.
`install.sh` backs up any existing `~/.vimrc` so this repo wins.

### Why `~/.vimrc.local`?

Per-machine tweaks (work-laptop credentials, host-specific paths, theme
overrides) shouldn't pollute the shared config. `vimrc` sources
`~/.vimrc.local` last, and it's intentionally untracked.

### Why build `telescope-fzf-native` at install time?

It's a tiny C extension that makes telescope's fuzzy matcher 10–100×
faster on large repos. The install script handles it transparently if
`make` and a C compiler are present, and proceeds without it if not.

---

## 🗂️ Repository layout

```
.vim/
├── vimrc                shared options/maps/classic-plugin config
├── init.lua             nvim entrypoint (sources vimrc, then loads lua/)
├── install.sh           bootstrap (symlinks + submodule init + helptags)
├── Makefile             install / update / add / rm / helptags / doctor
├── lua/
│   ├── core/            options.lua, keymaps.lua, autocmds.lua  (nvim only)
│   └── plugins/         per-plugin setup modules
├── plugin/  after/  ftplugin/  ftdetect/  colors/  snippets/  doc/
└── pack/
    ├── shared/start/    vimscript plugins, both editors (auto-loaded)
    ├── nvim/opt/        Lua plugins, packadd!'d by nvim only
    └── vim/start/       (reserved for vim-only fallbacks)
```

`pack/shared/start/*` is loaded automatically by **both** vim and nvim.
`pack/nvim/opt/*` is loaded by `lua/plugins/init.lua` via `packadd!`, so vim
never touches the Lua-only plugins.

---

## 🔌 Plugin roster

### 🤝 Shared (vim + nvim) — `pack/shared/start/`

| Plugin                               | Role                      | Notes                                                     |
| ------------------------------------ | ------------------------- | --------------------------------------------------------- |
| 🌳 `tpope/vim-fugitive`               | Git porcelain             | `:Git`, `:Gdiffsplit`, `:Git blame`                       |
| 🪢 `tpope/vim-surround`               | Surround text objects     | `cs`, `ds`, `ys{motion}`                                  |
| 💬 `tpope/vim-commentary`             | Toggle comments           | `gc{motion}`, `gcc`                                       |
| 🔁 `tpope/vim-repeat`                 | Make `.` work for plugins | Required by surround & friends                            |
| 🧪 `tpope/vim-sleuth`                 | Auto-detect indent        | Sets `tabstop` / `expandtab` from buffer contents         |
| 🅱️ `tpope/vim-unimpaired`             | `[`/`]` bracket maps      | `[b`, `]b`, `[q`, `]q`, …                                 |
| 🛠️ `tpope/vim-eunuch`                 | Unix shell helpers        | `:Move`, `:Rename`, `:Delete`, `:SudoWrite`               |
| 🔍 `junegunn/fzf` + `fzf.vim`         | Fuzzy finder              | `<C-p>` files, `<leader>fb` buffers, `<leader>fg` ripgrep |
| 📐 `editorconfig/editorconfig-vim`    | `.editorconfig` support   | Honors per-repo formatting                                |
| 🎨 `morhetz/gruvbox`                  | Primary colorscheme       | Falls back to `habamax` if missing                        |
| 🟢 `airblade/vim-gitgutter`           | Hunk signs                | **vim only** — nvim uses `gitsigns`                       |
| 🌲 `preservim/nerdtree`               | File tree                 | **vim only** — nvim uses `nvim-tree`                      |
| 🌐 `sheerun/vim-polyglot`             | Syntax for ~600 languages | **vim only** — nvim uses `nvim-treesitter`                |
| ⚠️ `dense-analysis/ale`               | Async lint                | **vim only** — nvim uses LSP diagnostics                  |
| ✈️ `vim-airline/vim-airline` + themes | Statusline                | **vim only** — nvim uses `lualine`                        |

> 🔒 The five "vim only" entries are guarded by `if !has('nvim')` blocks in
> `vimrc`, so they're inert under nvim.

### 🟩 Neovim-only — `pack/nvim/opt/`

| Plugin                                                                             | Role                              |
| ---------------------------------------------------------------------------------- | --------------------------------- |
| 🧱 `nvim-lua/plenary.nvim`                                                          | Lua stdlib (dependency)           |
| 🔌 `neovim/nvim-lspconfig`                                                          | LSP server configurations         |
| 🧰 `williamboman/mason.nvim` + `mason-lspconfig.nvim`                               | Install LSP / DAP / lint binaries |
| ✍️ `hrsh7th/nvim-cmp` + `cmp-nvim-lsp` / `cmp-buffer` / `cmp-path`                  | Completion engine + sources       |
| ✂️ `L3MON4D3/LuaSnip` + `saadparwaiz1/cmp_luasnip` + `rafamadriz/friendly-snippets` | Snippet engine + library          |
| 🌳 `nvim-treesitter/nvim-treesitter` (+ `-textobjects`)                             | Syntax / indent / folds / objects |
| 🔭 `nvim-telescope/telescope.nvim` + `telescope-fzf-native.nvim`                    | Fuzzy picker (with C matcher)     |
| 📊 `nvim-lualine/lualine.nvim`                                                      | Statusline                        |
| 🧬 `lewis6991/gitsigns.nvim`                                                        | Hunk signs / blame / staging      |
| 🌲 `nvim-tree/nvim-tree.lua` + `nvim-web-devicons`                                  | File explorer + icons             |
| 🗝️ `folke/which-key.nvim`                                                           | Keymap hint popups                |
| 🔗 `windwp/nvim-autopairs`                                                          | Auto-close brackets / quotes      |
| 🌈 `catppuccin/nvim`, `folke/tokyonight.nvim`                                       | Alternate colorschemes            |

---

## 🛠️ LSP servers (auto-installed by Mason)

Defined in `lua/plugins/lsp.lua` via `ensure_installed`:

| Server          | Language(s)             | External requirement   |
| --------------- | ----------------------- | ---------------------- |
| `pyright`       | Python                  | `node`                 |
| `gopls`         | Go                      | `go`                   |
| `ts_ls`         | TypeScript / JavaScript | `node`                 |
| `rust_analyzer` | Rust                    | `rustup` (recommended) |
| `lua_ls`        | Lua (incl. nvim config) | none                   |
| `bashls`        | Bash / sh               | `node`                 |
| `yamlls`        | YAML                    | `node`                 |
| `jsonls`        | JSON                    | `node`                 |
| `taplo`         | TOML                    | none (Rust binary)     |
| `marksman`      | Markdown                | none                   |
| `terraformls`   | Terraform / HCL         | none                   |
| `dockerls`      | Dockerfile              | `node`                 |

All of them are managed via `:Mason` and live in
`~/.local/share/nvim/mason/`.

---

## ⌨️ Key mappings cheatsheet

Leader is `\` (backslash). `<localleader>` is also `\`.

### 🌍 Shared (defined in `vimrc`)

| Mapping                   | Action                         |
| ------------------------- | ------------------------------ |
| `<leader><space>`         | Clear search highlight         |
| `<leader>w` / `<leader>q` | `:w` / `:q`                    |
| `<C-h/j/k/l>`             | Window navigation              |
| `[b` / `]b`               | Previous / next buffer         |
| `<leader>bd`              | Delete buffer                  |
| `<` / `>` (visual)        | Indent and keep selection      |
| `n` / `N`                 | Next / prev search, recentered |
| `Y`                       | Yank to end of line            |

### 🔍 fzf.vim (shared)

| Mapping      | Action          |
| ------------ | --------------- |
| `<C-p>`      | `:Files`        |
| `<leader>fb` | `:Buffers`      |
| `<leader>fl` | `:Lines`        |
| `<leader>fg` | `:Rg` (ripgrep) |

### 🌳 fugitive (shared)

| Mapping      | Action        |
| ------------ | ------------- |
| `<leader>gs` | `:Git`        |
| `<leader>gd` | `:Gdiffsplit` |
| `<leader>gb` | `:Git blame`  |

### 🟢 gitgutter (vim only — nvim uses gitsigns)

| Mapping      | Action           |
| ------------ | ---------------- |
| `]h` / `[h`  | Next / prev hunk |
| `<leader>hs` | Stage hunk       |
| `<leader>hu` | Undo hunk        |

### 🟩 Neovim LSP (defined in `lua/plugins/lsp.lua`)

| Mapping      | Action                   |
| ------------ | ------------------------ |
| `gd` / `gD`  | Definition / declaration |
| `gr`         | References               |
| `gi`         | Implementation           |
| `K`          | Hover                    |
| `<C-k>`      | Signature help           |
| `<leader>rn` | Rename                   |
| `<leader>ca` | Code action              |
| `<leader>fF` | Format buffer (async)    |
| `[d` / `]d`  | Prev / next diagnostic   |

---

## 🧰 Daily commands

| Command         | What it does                                                 |
| --------------- | ------------------------------------------------------------ |
| `make install`  | Run `install.sh` (symlinks + submodule init + helptags).     |
| `make update`   | `git submodule update --remote --merge --jobs 8` + helptags. |
| `make helptags` | Regenerate vim + nvim helptags only.                         |
| `make doctor`   | Run `:checkhealth` headlessly under nvim.                    |
| `make list`     | List vendored plugins per bundle.                            |
| `make clean`    | Remove the `~/.vim` and `~/.config/nvim` symlinks.           |

---

## ➕ Adding / removing plugins

```sh
# add: BUNDLE=shared (vim+nvim) or BUNDLE=nvim (Lua-only)
make add PLUGIN=tpope/vim-rhubarb        BUNDLE=shared
make add PLUGIN=folke/trouble.nvim       BUNDLE=nvim

# remove
make rm  PLUGIN=trouble.nvim BUNDLE=nvim
```

After adding a new **shared** plugin, restart vim/nvim — `pack/*/start/*` is
auto-loaded. After adding a new **nvim** plugin, either restart or
`:packadd <name>` and create a setup module under `lua/plugins/`.

---

## 🏠 Per-machine overrides

Drop machine-local tweaks in `~/.vimrc.local` — `vimrc` sources it last and
it is never tracked by this repo. Examples:

```vim
" ~/.vimrc.local
colorscheme tokyonight
let g:airline_theme = 'tokyonight'
nnoremap <leader>x :Files ~/work<CR>
```

---

## 🧱 Use as a submodule of another dotfiles repo

```sh
cd ~/dot
git submodule add git@github.com:<you>/.vim.git .vim
git submodule update --init --recursive
./.vim/install.sh
```

When cloning the parent repo: `git clone --recurse-submodules`.

---

## 🔄 Updating / pinning plugins

`make update` runs `git submodule update --remote --merge --jobs 8` on every
submodule and regenerates helptags. To **pin** a specific plugin to a tag
instead of floating on `HEAD`:

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

---

## 🩺 Troubleshooting

- ❌ **`E185: Cannot find color scheme 'gruvbox'`** — submodules not
  initialized. Run `git submodule update --init --recursive --depth 1`.
- 🐢 **Slow nvim startup** — profile it:
  `nvim --startuptime /tmp/start.log +qa` and inspect the log.
- 🩺 **LSP not attaching** — `:LspInfo`. If a server is missing, run
  `:Mason` and install it; verify the language toolchain (e.g. `node`,
  `go`) is on your `PATH`.
- 🧱 **`telescope-fzf-native` warning** — re-run
  `make -C pack/nvim/opt/telescope-fzf-native.nvim`. Requires a C compiler.
- 🔠 **Icons render as boxes / question marks** — install a
  [Nerd Font] and configure your terminal to use it.
- 🎨 **Colors look washed out** — your terminal isn't true-color. Either
  enable 24-bit color or `set notermguicolors` in `~/.vimrc.local`.
- 🛠️ **Mason install fails** — ensure `unzip`, `curl`, and `tar` are on
  `PATH`, plus the language runtime each server needs (see
  [LSP servers](#️-lsp-servers-auto-installed-by-mason)).
- 🔍 **A command (e.g. `:Mason`, `:Telescope`, `:Gitsigns`) doesn't
  exist or autocomplete** — the plugin is staged on disk but not loaded
  in the editor you're using. Run `make plugins` (or
  `bash scripts/plugin-status.sh`) for a per-editor matrix; entries marked
  📦 are vendored but inert. The canonical case: `:Mason` only exists in
  nvim — `mason.nvim` lives under `pack/nvim/opt/` and is `packadd!`'d
  exclusively by `lua/plugins/init.lua`, so vim never sees the command.
- 🪟 **Symlink not created on Windows / WSL** — run `install.sh` from inside
  WSL, or use `mklink /D` manually on native Windows.

[Nerd Font]: https://www.nerdfonts.com/
