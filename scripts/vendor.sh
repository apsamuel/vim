#!/usr/bin/env bash
# scripts/vendor.sh — add every plugin submodule.
# Idempotent: skips entries whose target directory is already a non-empty repo.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO="$(pwd -P)"

SHARED=(
  tpope/vim-fugitive
  tpope/vim-surround
  tpope/vim-commentary
  tpope/vim-repeat
  tpope/vim-sleuth
  tpope/vim-unimpaired
  tpope/vim-eunuch
  airblade/vim-gitgutter
  junegunn/fzf
  junegunn/fzf.vim
  preservim/nerdtree
  editorconfig/editorconfig-vim
  sheerun/vim-polyglot
  dense-analysis/ale
  morhetz/gruvbox
  vim-airline/vim-airline
  vim-airline/vim-airline-themes
)

NVIM=(
  nvim-lua/plenary.nvim
  neovim/nvim-lspconfig
  williamboman/mason.nvim
  williamboman/mason-lspconfig.nvim
  hrsh7th/nvim-cmp
  hrsh7th/cmp-nvim-lsp
  hrsh7th/cmp-buffer
  hrsh7th/cmp-path
  L3MON4D3/LuaSnip
  saadparwaiz1/cmp_luasnip
  rafamadriz/friendly-snippets
  nvim-treesitter/nvim-treesitter
  nvim-treesitter/nvim-treesitter-textobjects
  nvim-telescope/telescope.nvim
  nvim-telescope/telescope-fzf-native.nvim
  nvim-lualine/lualine.nvim
  lewis6991/gitsigns.nvim
  nvim-tree/nvim-tree.lua
  nvim-tree/nvim-web-devicons
  folke/which-key.nvim
  windwp/nvim-autopairs
  catppuccin/nvim
  folke/tokyonight.nvim
)

add_one() {
  local owner_repo="$1" dest_root="$2"
  local name="${owner_repo##*/}"
  local dest="$dest_root/$name"
  if [[ -d "$REPO/$dest/.git" || -f "$REPO/$dest/.git" ]]; then
    echo "[skip]  $dest"
    return 0
  fi
  echo "[add]   $owner_repo -> $dest"
  git -C "$REPO" submodule add --depth 1 -q \
    "https://github.com/${owner_repo}.git" "$dest"
}

for repo in "${SHARED[@]}"; do
  add_one "$repo" "pack/shared/start"
done

# catppuccin/nvim collides with the directory name; rename it for clarity.
for repo in "${NVIM[@]}"; do
  add_one "$repo" "pack/nvim/opt"
done

echo
echo "[done] vendored: ${#SHARED[@]} shared, ${#NVIM[@]} nvim"
