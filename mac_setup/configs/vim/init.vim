" =============================================================================
" Neovim Configuration - managed by mac_setup
" =============================================================================

let mapleader = "\\"

" ---------------------------------------------------------------------------
" Core settings
" ---------------------------------------------------------------------------
set cursorline
set hlsearch
set autoindent
set expandtab
set tabstop=2
set shiftwidth=2
set showmatch
set mouse=a
set number
set relativenumber
set signcolumn=yes
set autoread
set updatetime=100
set noswapfile
set termguicolors
set ignorecase
set smartcase
set hidden
set encoding=utf-8

" Disable arrow keys (vim discipline)
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>
inoremap <Up> <Nop>
inoremap <Down> <Nop>
inoremap <Left> <Nop>
inoremap <Right> <Nop>

" Auto-reload files changed outside vim
autocmd FocusGained,BufEnter * checktime

" ---------------------------------------------------------------------------
" vim-plug
" ---------------------------------------------------------------------------
set rtp+=~/.vim
call plug#begin('~/.vim/plugged')

" Theme
Plug 'folke/tokyonight.nvim'

" Status line
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" File navigation
Plug 'preservim/nerdtree'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }

" Git
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" Treesitter
Plug 'nvim-treesitter/nvim-treesitter', { 'do': ':TSUpdate' }
Plug 'nvim-treesitter/nvim-treesitter-textobjects'

" Go
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
Plug 'ray-x/go.nvim'
Plug 'ray-x/guihua.lua', { 'do': 'cd lua/fzy && make' }
Plug 'maxandron/goplements.nvim'
Plug 'neovim/nvim-lspconfig'

" Python
Plug 'python-mode/python-mode', { 'for': 'python', 'branch': 'develop' }
Plug 'davidhalter/jedi-vim'
Plug 'psf/black', { 'branch': 'stable' }

" YAML / JSON
Plug 'stephpy/vim-yaml'
Plug 'elzr/vim-json'
Plug 'someone-stole-my-name/yaml-companion.nvim'

" Docker
Plug 'ekalinin/Dockerfile.vim'

" Markdown
Plug 'preservim/vim-markdown'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug'] }

" Protobuf
Plug 'uarun/vim-protobuf'

" Linting
Plug 'dense-analysis/ale'

" AI
Plug 'yetone/avante.nvim', { 'branch': 'main', 'do': 'make' }
Plug 'MunifTanjim/nui.nvim'
Plug 'stevearc/dressing.nvim'
Plug 'coder/claudecode.nvim'

" Utilities
Plug 'akinsho/toggleterm.nvim'
Plug 'jiangmiao/auto-pairs'

call plug#end()

" ---------------------------------------------------------------------------
" Theme: Tokyo Night
" ---------------------------------------------------------------------------
lua << EOF
local ok, tokyonight = pcall(require, 'tokyonight')
if ok then
  tokyonight.setup({
    style = "night",
    transparent = false,
    terminal_colors = true,
    styles = {
      comments = { italic = true },
      keywords = { italic = true },
    },
    sidebars = { "NERDTree", "qf", "help", "terminal" },
    on_colors = function(colors)
      colors.bg_sidebar = "#13131a"
    end,
  })
end
EOF
silent! colorscheme tokyonight-night

" ---------------------------------------------------------------------------
" Airline
" ---------------------------------------------------------------------------
let g:airline_theme = 'deus'
let g:airline_powerline_fonts = 1
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#hunks#enabled = 1

" ---------------------------------------------------------------------------
" NERDTree
" ---------------------------------------------------------------------------
nnoremap <C-n> :NERDTreeFocus<CR>
nnoremap <Leader>g :NERDTreeFind<CR>
nnoremap <Leader>n :NERDTreeToggle<CR>
let g:NERDTreeWinSize = 35
let g:NERDTreeShowHidden = 1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) | exe 'NERDTree' argv()[0] | wincmd p | enew | endif
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

" ---------------------------------------------------------------------------
" Telescope
" ---------------------------------------------------------------------------
lua << EOF
local ok, telescope = pcall(require, 'telescope')
if ok then
  telescope.setup({
    defaults = {
      layout_strategy = 'horizontal',
      layout_config = {
        prompt_position = 'top',
      },
      sorting_strategy = 'ascending',
      file_ignore_patterns = {
        "node_modules/",
        ".git/",
        "vendor/",
        "__pycache__/",
      },
    },
    pickers = {
      find_files = { hidden = true },
    },
  })
  pcall(telescope.load_extension, 'fzf')
end
EOF

" ---------------------------------------------------------------------------
" Treesitter
" ---------------------------------------------------------------------------
lua << EOF
local ok, ts = pcall(require, 'nvim-treesitter.configs')
if ok then
  ts.setup({
    ensure_installed = {
      "go", "python", "yaml", "json", "hcl", "proto",
      "bash", "lua", "markdown", "markdown_inline",
      "dockerfile", "sql", "toml",
    },
    highlight = { enable = true },
    indent = { enable = true },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<C-space>",
        node_incremental = "<C-space>",
      },
    },
    textobjects = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          ["ic"] = "@class.inner",
          ["aa"] = "@parameter.outer",
          ["ia"] = "@parameter.inner",
        },
      },
      move = {
        enable = true,
        set_jumps = true,
        goto_next_start = {
          ["]f"] = "@function.outer",
          ["]c"] = "@class.outer",
        },
        goto_previous_start = {
          ["[f"] = "@function.outer",
          ["[c"] = "@class.outer",
        },
      },
    },
  })
end
EOF

" ---------------------------------------------------------------------------
" Go
" ---------------------------------------------------------------------------
lua << EOF
local ok_go, go = pcall(require, 'go')
if ok_go then
  go.setup()
end

local ok_gop, goplements = pcall(require, 'goplements')
if ok_gop then
  goplements.setup()
end
EOF

" ---------------------------------------------------------------------------
" Toggleterm
" ---------------------------------------------------------------------------
lua << EOF
local ok, toggleterm = pcall(require, 'toggleterm')
if ok then
  toggleterm.setup({
    open_mapping = [[<C-\>]],
    direction = 'horizontal',
    size = 15,
  })
end
EOF

" ---------------------------------------------------------------------------
" Claude Code integration
" ---------------------------------------------------------------------------
lua << EOF
local ok, claudecode = pcall(require, 'claudecode')
if ok then
  claudecode.setup({
    auto_start = true,
  })
end
EOF

" ---------------------------------------------------------------------------
" Git
" ---------------------------------------------------------------------------
nnoremap <Leader>gg :Git<CR>
nnoremap <Leader>gb :Git blame<CR>
nnoremap <Leader>gl :Git log<CR>
let g:gitgutter_enabled = 1
let g:gitgutter_sign_added = '+'
let g:gitgutter_sign_modified = '~'
let g:gitgutter_sign_removed = '-'
nmap ]c <Plug>(GitGutterNextHunk)
nmap [c <Plug>(GitGutterPrevHunk)

" ---------------------------------------------------------------------------
" Python
" ---------------------------------------------------------------------------
let g:pymode_python = 'python3'
autocmd BufWritePre *.py execute ':Black'

" ---------------------------------------------------------------------------
" JSON / Markdown
" ---------------------------------------------------------------------------
let g:vim_json_syntax_conceal = 0
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_conceal = 0
let g:vim_markdown_fenced_languages = ['go', 'python', 'bash=sh', 'json', 'yaml', 'sql', 'javascript=js', 'typescript=ts']
let g:mkdp_theme = 'dark'
nmap <Leader>mp <Plug>MarkdownPreview
nmap <Leader>ms <Plug>MarkdownPreviewStop

" ---------------------------------------------------------------------------
" Key bindings
" ---------------------------------------------------------------------------
" Telescope
nnoremap <Leader>p  <cmd>Telescope find_files<cr>
nnoremap <Leader>fg <cmd>Telescope live_grep<cr>
nnoremap <Leader>fb <cmd>Telescope buffers<cr>
nnoremap <Leader>fh <cmd>Telescope help_tags<cr>
nnoremap <Leader>fs <cmd>Telescope lsp_document_symbols<cr>
nnoremap <Leader>fr <cmd>Telescope lsp_references<cr>
nnoremap <Leader>fd <cmd>Telescope diagnostics<cr>
nnoremap <Leader>fc <cmd>Telescope git_commits<cr>

" Save, quit, windows
nnoremap <Leader>s :wa<CR>
nnoremap <Leader>q :qa<CR>
nnoremap <Leader>! :qa!<CR>
nnoremap <Leader>w :close<CR>
nnoremap <Leader>v :vsplit<CR>
nnoremap <Leader>h :split<CR>:resize 12<CR>
nnoremap <Leader>t :terminal<CR>

" Escape shortcuts
inoremap jj <Esc>:w<CR>
inoremap \\ <Esc>
nnoremap <S-Enter> O<Esc>
nnoremap <CR> o<Esc>

" Restore natural keys in quickfix and NERDTree
autocmd BufReadPost quickfix nnoremap <buffer> <CR> <CR>
autocmd FileType nerdtree nmap <buffer> <CR> o
autocmd FileType nerdtree noremap <buffer> <Up> <Up>
autocmd FileType nerdtree noremap <buffer> <Down> <Down>
autocmd FileType nerdtree nmap <buffer> <Left> x
autocmd FileType nerdtree nmap <buffer> <Right> o

" ---------------------------------------------------------------------------
" Local overrides (never committed)
" ---------------------------------------------------------------------------
if filereadable(expand('~/.config/nvim/init.local.vim'))
  source ~/.config/nvim/init.local.vim
endif
