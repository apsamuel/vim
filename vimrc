" =============================================================================
" vimrc — shared configuration for vim 8+ and neovim
" Sourced directly by vim; sourced from init.lua by neovim.
" Plugin manager: vim 8 native packages (pack/<bundle>/{start,opt}/<plugin>).
" =============================================================================

set nocompatible

" ---- Leader -----------------------------------------------------------------
let mapleader = "\\"
let maplocalleader = "\\"

" ---- Core options -----------------------------------------------------------
set encoding=utf-8
scriptencoding utf-8
set fileencoding=utf-8

set hidden
set number
set relativenumber
set cursorline
set ruler
set showcmd
set showmatch
set wildmenu
set wildmode=longest:full,full
set laststatus=2
set noshowmode           " statusline plugins display the mode
set signcolumn=yes
set scrolloff=8
set sidescrolloff=8
set splitright
set splitbelow
set lazyredraw
set ttyfast
set updatetime=300
set timeoutlen=500
set mouse=a
set clipboard^=unnamed,unnamedplus
set backspace=indent,eol,start
set history=1000
set autoread

" search
set ignorecase
set smartcase
set incsearch
set hlsearch

" indent
set autoindent
set smartindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set shiftround

" wrap / display
set nowrap
set linebreak
set display=lastline
set list
set listchars=tab:»·,trail:·,nbsp:␣,extends:›,precedes:‹

" persistence
set undofile
if has('nvim')
  let s:undodir = stdpath('state') . '/undo'
else
  let s:undodir = expand('~/.vim/.cache/undo')
endif
if !isdirectory(s:undodir)
  call mkdir(s:undodir, 'p', 0700)
endif
let &undodir = s:undodir
set nobackup
set nowritebackup
set noswapfile

" colors / GUI
if has('termguicolors')
  set termguicolors
endif
set background=dark

" filetype + syntax
filetype plugin indent on
syntax enable

" ---- Sane mappings ----------------------------------------------------------
" clear search highlight
nnoremap <silent> <leader><space> :nohlsearch<CR>

" save / quit shortcuts
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" buffer navigation
nnoremap <silent> [b :bprevious<CR>
nnoremap <silent> ]b :bnext<CR>
nnoremap <silent> <leader>bd :bdelete<CR>

" keep selection after indent
xnoremap < <gv
xnoremap > >gv

" center search jumps
nnoremap n nzzzv
nnoremap N Nzzzv

" yank to end of line consistency
nnoremap Y y$

" ---- Filetype tweaks --------------------------------------------------------
augroup vimrc_filetypes
  autocmd!
  autocmd FileType yaml,json,html,css,scss,javascript,typescript,typescriptreact,javascriptreact,lua,terraform,hcl
        \ setlocal tabstop=2 shiftwidth=2 softtabstop=2
  autocmd FileType go setlocal noexpandtab tabstop=4 shiftwidth=4
  autocmd FileType make setlocal noexpandtab
  autocmd FileType gitcommit setlocal spell textwidth=72
  autocmd FileType markdown setlocal spell wrap linebreak
augroup END

" restore last cursor position
augroup vimrc_lastpos
  autocmd!
  autocmd BufReadPost *
        \ if line("'\"") >= 1 && line("'\"") <= line("$") && &filetype !~# 'commit'
        \ |   execute 'normal! g`"'
        \ | endif
augroup END

" trim trailing whitespace on save (skip markdown)
augroup vimrc_trim
  autocmd!
  autocmd BufWritePre * if &filetype !~# 'markdown\|diff' | %s/\s\+$//e | endif
augroup END

" =============================================================================
" Plugin configuration
" Plugins under pack/shared/start/ load automatically for both editors.
" Plugins replaced by Lua equivalents in nvim are gated `if !has('nvim')`.
" =============================================================================

" ---- shared (both editors) --------------------------------------------------

" fzf.vim
if executable('fzf') || isdirectory(expand('~/.vim/pack/shared/start/fzf'))
  nnoremap <silent> <C-p>      :Files<CR>
  nnoremap <silent> <leader>fb :Buffers<CR>
  nnoremap <silent> <leader>fl :Lines<CR>
  nnoremap <silent> <leader>fg :Rg<CR>
endif

" vim-fugitive
nnoremap <leader>gs :Git<CR>
nnoremap <leader>gd :Gdiffsplit<CR>
nnoremap <leader>gb :Git blame<CR>

" editorconfig — no config needed, just present
" vim-sleuth — no config needed
" vim-commentary — gc{motion}
" vim-surround — cs/ds/ys

" ---- vim-only (skipped under nvim, which has Lua replacements) -------------
if !has('nvim')

  " NERDTree
  if isdirectory(expand('~/.vim/pack/shared/start/nerdtree'))
    nnoremap <silent> <leader>e :NERDTreeToggle<CR>
    nnoremap <silent> <leader>o :NERDTreeFind<CR>
    let g:NERDTreeMinimalUI = 1
    let g:NERDTreeShowHidden = 1
    let g:NERDTreeIgnore = ['\.git$', '\.DS_Store$', '__pycache__$', '\.pyc$']
  endif

  " vim-airline
  if isdirectory(expand('~/.vim/pack/shared/start/vim-airline'))
    let g:airline_powerline_fonts = 1
    let g:airline#extensions#tabline#enabled = 1
    let g:airline#extensions#tabline#formatter = 'unique_tail'
    let g:airline_theme = 'gruvbox'
  endif

  " gitgutter
  if isdirectory(expand('~/.vim/pack/shared/start/vim-gitgutter'))
    set updatetime=300
    let g:gitgutter_map_keys = 0
    nmap ]h <Plug>(GitGutterNextHunk)
    nmap [h <Plug>(GitGutterPrevHunk)
    nmap <leader>hs <Plug>(GitGutterStageHunk)
    nmap <leader>hu <Plug>(GitGutterUndoHunk)
  endif

  " ALE — async lint when no LSP is available
  if isdirectory(expand('~/.vim/pack/shared/start/ale'))
    let g:ale_fix_on_save = 0
    let g:ale_lint_on_text_changed = 'never'
    let g:ale_lint_on_insert_leave = 1
    let g:ale_sign_error = '✗'
    let g:ale_sign_warning = '⚠'
  endif

endif " !has('nvim')

" ---- Colorscheme ------------------------------------------------------------
" Try gruvbox; fall back gracefully if the submodule has not been initialized.
function! s:try_colorscheme(name) abort
  try
    execute 'colorscheme' a:name
    return 1
  catch /^Vim\%((\a\+)\)\=:E185/
    return 0
  endtry
endfunction

if !s:try_colorscheme('gruvbox')
  call s:try_colorscheme('habamax')
endif

" =============================================================================
" Local overrides — optional per-machine file, never committed.
" =============================================================================
if filereadable(expand('~/.vimrc.local'))
  source ~/.vimrc.local
endif
