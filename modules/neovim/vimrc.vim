" ============================================================================
"     Maintainer:
"     Simon W. Jackson    @simonwjackson
" ============================================================================

" ============================================================================
" => Helper Functions
" ============================================================================

" ----------------------------------------------------------------------------
"  - Restore cursor, window, and last search after running a command.
" ----------------------------------------------------------------------------

function! Preserve(command)
    " Save the last search.

    " Save the current cursor position.
    let search = @/
    let cursor_position = getpos('.')

    " Save the current window position.
    normal! H
    let window_position = getpos('.')
    call setpos('.', cursor_position)

    " Execute the command.
    execute a:command

    " Restore the last search.
    let @/ = search

    " Restore the previous window position.
    call setpos('.', window_position)
    normal! zt                  

    " Restore the previous cursor position.
    call setpos('.', cursor_position)
endfunction


" ----------------------------------------------------------------------------
"  - Fill the command line with..
" ----------------------------------------------------------------------------

function! CmdLine(str)
    call feedkeys(":" . a:str)
endfunction


" ----------------------------------------------------------------------------
"  - Return the open file's parent directory
" ----------------------------------------------------------------------------

function! CurrentFileDir(cmd)
    return a:cmd . " " . expand("%:p:h") . "/"
endfunction

function! LazyGitPopup()
    if executable('tmux') && strlen($TMUX)
        silent execute '!tmux new-window -a lazygit &'
    else
        LazyGit
    endif
endfunction


" ====================================================
"  => Plugins
" ====================================================

" Install vim-plug if needed
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
    silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.local/share/nvim/plugged')

" ----------------------------------------------------
"  - Themes
" ----------------------------------------------------

Plug 'flrnprz/plastic.vim'
Plug 'lifepillar/vim-solarized8'
Plug 'Mofiqul/dracula.nvim'

" ----------------------------------------------------
"  - Language Support
" ----------------------------------------------------

Plug 'nvim-treesitter/playground'

" TODO: 

" Rofi
Plug 'Fymyte/rasi.vim'

Plug 'nikolvs/vim-sunbather'

" Golang
" Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

" Jinja2
Plug 'Glench/Vim-Jinja2-Syntax'

" Cucumber
Plug 'tpope/vim-cucumber'

" Elm
Plug 'andys8/vim-elm-syntax' 

" MDX
Plug 'jxnblk/vim-mdx-js'

" Docker
Plug 'ekalinin/dockerfile.vim'

" Git
Plug 'tpope/vim-git'

" A Vim syntax highlighting plugin for JavaScript and Flow.js
" Plug 'yuezk/vim-js' 

" The React syntax highlighting and indenting plugin for vim.
" Also supports the typescript tsx file.
" Plug 'maxmellon/vim-jsx-pretty'

" Distinct highlighting of keywords vs values, 
" JSON-specific (non-JS) warnings, quote concealing.
Plug 'elzr/vim-json'

" JSONC (with comments)
Plug 'neoclide/jsonc.vim'

" A Vim plugin that provides GraphQL file detection, syntax highlighting, and indentation.
Plug 'jparise/vim-graphql'

" quoting/parenthesizing made simple
Plug 'tpope/vim-surround'

" source ~/.config/nvim/plugins/gitgutter.vim
" Plug 'airblade/vim-gitgutter'
" source ~/.config/nvim/plugins/which-key.vim
" source ~/.config/nvim/plugins/bspwm.vim


" Modify * to also work with visual selections.
Plug 'nelstrom/vim-visual-star-search'

" Automatically clear search highlights after you move your cursor.
Plug 'haya14busa/is.vim'

" Seamless navigation between tmux panes and vim splits
Plug 'christoomey/vim-tmux-navigator'

" Vim sugar for the UNIX shell commands that need it the most
Plug 'tpope/vim-eunuch'



" ----------------------------------------------------------------------------
"  - Extras
" ----------------------------------------------------------------------------

" True Sublime Text style multiple selections for Vim
Plug 'terryma/vim-multiple-cursors'

" Adds file type icons to Vim plugins
Plug 'ryanoasis/vim-devicons'

" source ~/.config/nvim/plugins/goyo.vim
" source ~/.config/nvim/plugins/limelight.vim

" fzf for vim
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'

" Use fzf instead of coc.nvim built-in fuzzy finder.  
" Plug 'antoinemadec/coc-fzf' 


" source ~/.config/nvim/plugins/fugitive.vim
" source ~/.config/nvim/plugins/nerdcommenter.vim

" Improved * motions
Plug 'haya14busa/vim-asterisk'

" Briefly highlight which text was yanked.
Plug 'machakann/vim-highlightedyank'

" Modify * to also work with visual selections.
Plug 'nelstrom/vim-visual-star-search'


" FocusGained and FocusLost for vim inside Tmux
" This is a plugin for Vim to dim inactive windows.  
Plug 'tmux-plugins/vim-tmux-focus-events' 

" An eye friendly plugin that fades your inactive buffers and preserves your syntax highlighting!
" Plug 'TaDaa/vimade'

" Proper project management in vim.
Plug 'tools-life/taskwiki'

" Taskwarrior in VIM
" Plug 'farseer90718/vim-taskwarrior'

" Zettelkasten for VIM
Plug 'michal-h21/vim-zettel'

" source ~/.config/nvim/plugins/telescope.vim
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
" Plug 'fannheyward/telescope-coc.nvim'
Plug 'nvim-telescope/telescope.nvim'

" Icons
Plug 'kyazdani42/nvim-web-devicons'

" Auto Sessions
" Plug 'rmagatti/auto-session'
" Plug 'rmagatti/session-lens'

" Todo Comments
Plug 'folke/todo-comments.nvim'

" Trouble
Plug 'folke/trouble.nvim'

" LazyGit
Plug 'kdheepak/lazygit.nvim'

" expand region (+/-)
Plug 'terryma/vim-expand-region'

" Ultisnips: Text Expansion
Plug 'SirVer/ultisnips'

" A multi-language debugging system for Vim 
Plug 'puremourning/vimspector'

" VIM Test
Plug 'vim-test/vim-test'
" Plug 'rcarriga/vim-ultest', { 'do': ':UpdateRemotePlugins' }

Plug 'pwntester/octo.nvim'
Plug 'tpope/vim-obsession'

Plug 'camgraff/telescope-tmux.nvim'
Plug 'RyanMillerC/better-vim-tmux-resizer'

" Swap windows without ruining your layout!
Plug 'wesQ3/vim-windowswap'

Plug 'ThePrimeagen/git-worktree.nvim'
Plug 'lmburns/lf.nvim'
" Plug 'Equilibris/nx.nvim'

Plug 'glacambre/firenvim', { 'do': { _ -> firenvim#install(0) } }

Plug 'MunifTanjim/eslint.nvim'


call plug#end()

set completeopt=menu,menuone,noselect


" ----------------------------------------------------------------------------
"  - Write to file even when it does not exist
" ----------------------------------------------------------------------------

function! s:WriteCreatingDirs()
    let l:file=expand("%")
    if empty(getbufvar(bufname("%"), '&buftype')) && l:file !~# '\v^\w+\:\/'
        let dir=fnamemodify(l:file, ':h')
        if !isdirectory(dir)
            call mkdir(dir, 'p')
        endif
    endif
    write
endfunction

command! W call s:WriteCreatingDirs()


" ----------------------------------------------------------------------------
"  - Use K to show documentation in preview window
" ----------------------------------------------------------------------------
" nnoremap <silent> K :call <SID>show_documentation()<CR>
" 
" function! s:show_documentation()
"     if (index(['vim','help'], &filetype) >= 0)
"         execute 'h '.expand('<cword>')
"     else
"         call CocActionAsync('doHover')
"     endif
" endfunction




" Explorer

"nmap <leader>e :CocCommand explorer<CR>
"nmap <leader>0 :CocCommand explorer --preset floating<CR>
"autocmd BufEnter * if (winnr("$") == 1 && &filetype == 'coc-explorer') | q | endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Better chars for splits
set fillchars=stl\:─,vert\:\█   

" ...?
set nohidden

" Default encoding
set encoding=utf-8

" Use Unix as the standard file type
set ffs=unix,dos,mac

" Linebreak on 500 characters
set linebreak
set tw=500

"set autoindent
set smartindent
set wrap

" Be smart when using tabs ;)
set smarttab

" Use spaces for tab key
set expandtab

" Default shell
set shell=/bin/sh

" Fix backspace indent
set backspace=indent,eol,start

" Enable filetype plugins
filetype plugin on
filetype indent on

" Load settings written in the file
set modeline

" Sets how many lines of history VIM has to remember
set history=1000

" How often the UI updates
set updatetime=300

" Share clipboard
set clipboard+=unnamedplus


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Searching
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Use RipGrep for grepping
set grepprg=rg\ --vimgrep 

" Ignore case when searching
set ignorecase

" When searching try to be smart about cases
set smartcase

" Makes search act like search in modern browsers
set incsearch 

" For regular expressions turn magic on
set magic


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Undo
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set undolevels=1000                     
set undoreload=10000                    

" Persistent undo                       
if has("persistent_undo")               
    set undofile            
    set undodir=~/.local/share/nvim/undo
    set backupdir=~/.local/share/nvim/backup
    set directory=~/.local/share/nvim/backup
endif 

" ============================================================================
"  => Spell checking
" ============================================================================

" Toggle and untoggle spell checking
nnoremap <leader>ss :setlocal spell!<cr>

" Show a list of spelling suggestions
nnoremap <leader>sc :<C-u>Telescope spell_suggest <CR> 

" Automatically fix the last misspelled word and jump back to where you were.
nnoremap <leader>sp :normal! mz[s1z=`z<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Misc
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set mouse=a
map <ScrollWheelUp> <C-y>
map <ScrollWheelDown> <C-e>
map <C-ScrollWheelUp> <C-u>
map <C-ScrollWheelDown> <C-d>

" Jump to the last position when reopening a file
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

function! Indent()
    if (&ft=='typescript' || &ft=='typescriptreact' || &ft=='javascript' || &ft=='javascriptreact')
      :EslintFixAll
    elseif (&ft=='vim')
      " do nothing
    else
      :lua vim.lsp.buf.format()
    endif
endfunction

autocmd BufWritePre * call Indent()

" ----------------------------------------------------------------------------
"  - Shell
" ----------------------------------------------------------------------------

if exists('$SUDO_USER')
    set noswapfile
    set nobackup
    set nowritebackup
    set noundofile
endif


" ============================================================================
"  => VIM user interface
" ============================================================================ 

" Update term title but restore old title after leaving Vim
set title
set titleold=

" Motion timeouts
" set notimeout
" set ttimeout
" TODO: change help split based on screen orientation
" Force vertical help
" cabbrev help vert help

" TODO: change buffer split based on screen orientation
" split below, not above
set splitbelow

" split right, not left
set splitright            

" Show substitutions live
set inccommand=split      

" Keep lines above/below cursor
set scrolloff=5

" Avoid garbled characters in Chinese language windows OS
let $LANG='en'
set langmenu=en

" Force vertical help
cabbrev help vert help

" Always show left column
set signcolumn=yes

" Don't redraw while executing macros (good performance config)
" set lazyredraw

" Show matching brackets when text indicator is over them
set showmatch

" How many tenths of a second to blink when matching brackets
set mat=2

" No annoying sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=500

" Disable line numbers
set nonumber

" Add a bit extra margin to the left
set foldcolumn=1

" Motion timeouts
" set notimeout
" set ttimeout

" Auto-resize splits when Vim gets resized.
autocmd VimResized * wincmd =

" Tab spaces
set tabstop=2
set shiftwidth=2
set softtabstop=0

" Auto format files on
" command! -nargs=0 Prettier :call CocAction('runCommand', 'prettier.formatFile')


" ============================================================================
" => Plugin configuration
" ============================================================================

" ----------------------------------------------------------------------------
"  - Tmux / Vim
" ----------------------------------------------------------------------------

let g:tmux_navigator_no_mappings = 1

" Disable tmux navigator when zooming the Vim pane
let g:tmux_navigator_disable_when_zoomed = 1

nnoremap <silent> <A-h> :TmuxNavigateLeft<cr>
nnoremap <silent> <A-j> :TmuxNavigateDown<cr>
nnoremap <silent> <A-k> :TmuxNavigateUp<cr>
nnoremap <silent> <A-l> :TmuxNavigateRight<cr>

let g:tmux_resizer_no_mappings = 1
let g:tmux_resizer_resize_count = 5
let g:tmux_resizer_vertical_resize_count = 10

function! ResizeLeft()
    "if exists('#goyo')
        "call feedkeys("5\<C-w>\<")
    "else
        TmuxResizeLeft
    "endif
endfunction

function! ResizeDown()
    "if exists('#goyo')
    "    call feedkeys("5\<C-w>\-")
    "else
        TmuxResizeDown
    "endif
endfunction

function! ResizeUp()
   " if exists('#goyo')
   "     call feedkeys("5\<C-w>\+")
   " else
        TmuxResizeUp
   " endif
endfunction

function! ResizeRight()
   " if exists('#goyo')
  "      call feedkeys("5\<C-w>\>")
   " else
        TmuxResizeRight
  "  endif
endfunction

nnoremap <silent> <A-S-Left>  :call ResizeLeft()<CR>
nnoremap <silent> <A-S-Down>  :call ResizeDown()<CR>
nnoremap <silent> <A-S-Up>    :call ResizeUp()<CR>
nnoremap <silent> <A-S-Right> :call ResizeRight()<CR>

nnoremap <silent> <A-S-C-Left>  :call ResizeLeft()<CR>
nnoremap <silent> <A-S-C-Down>  :call ResizeDown()<CR>
nnoremap <silent> <A-S-C-Up>    :call ResizeUp()<CR>
nnoremap <silent> <A-S-C-Right> :call ResizeRight()<CR>


" ----------------------------------------------------------------------------
"  - Vimade
" ----------------------------------------------------------------------------

" let g:vimade = { "fadelevel": 0.4 }
"
" au! FocusLost * VimadeFadeActive
" au! FocusGained * VimadeUnfadeActive




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" - vim-asterisk
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Keep cursor position across matches
let g:asterisk#keeppos = 1 



" ----------------------------------------------------------------------------
"  - Zettelkasten
" ----------------------------------------------------------------------------

let g:zettel_fzf_command = 'rg'



" ----------------------------------------------------------------------------
"  - Markdown
" ----------------------------------------------------------------------------

" function! s:markdown_enter()
"     " :Goyo
" endfunction
" 
" autocmd FileType markdown,markdown.mdx call <SID>markdown_enter() 


" ----------------------------------------------------------------------------
"  - Utilisnips
" ----------------------------------------------------------------------------

" Trigger configuration. You need to change this to something other than <tab> if you use one of the following:
" - https://github.com/Valloric/YouCompleteMe
" - https://github.com/nvim-lua/completion-nvim
" let g:UltiSnipsExpandTrigger="<tab>"
" let g:UltiSnipsJumpForwardTrigger="<c-b>"
" let g:UltiSnipsJumpBackwardTrigger="<c-z>"
" 
" " If you want :UltiSnipsEdit to split your window.
" let g:UltiSnipsEditSplit="vertical"


" ============================================================================
"  - Bindings
" ============================================================================

" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
let g:mapleader = "\<Space>"
let g:maplocalleader = ','


" ============================================================================
"  - Project navigation
" ============================================================================

" Finding Files
nnoremap <silent> <F6>      :<C-u>call LazyGitPopup()<CR>
nnoremap <silent> <F8>      <cmd>lua require('telescope.builtin').buffers()<cr>
nnoremap <silent> <F10>     :<C-u>Telescope oldfiles<CR>

" Finding code
nnoremap <silent> <F1>      :<C-u>SearchSession<CR>
nnoremap <silent> <F2>      :<C-u>Telescope live_grep<CR>
nnoremap          <F3>      :<C-u>TodoTelescope<CR>
nnoremap          <F4>      :<C-u>Telescope keymaps<CR>


" ============================================================================
"  - Motions
" ============================================================================

"nmap <silent> <Right> <Plug>(coc-range-select)
" xmap <silent> <Right> <Plug>(coc-range-select)

" Fix error under cursor
" nmap <silent> qf <Plug>(coc-fix-current)

" Show code actions
" nmap <silent> <leader>qf :<C-u>Telescope coc code_actions<CR> 

" nmap <silent> <Up> <Plug>(coc-diagnostic-prev)
" nmap <silent> <Down> <Plug>(coc-diagnostic-next)
" nmap <silent> <Down> :<C-u>call HandleDownKey()<CR>

" Goto definition of the symbol under the cursor
" nmap <silent> gd :<C-u>call CocActionAsync('jumpDefinition')<CR>

" Goto references of the symbol under the cursor
" nmap <silent> gr :<C-u>Telescope coc references<CR> 

" Goto references of the symbol under the cursor
" nmap <silent> gt :<C-u>Telescope coc type_definitions<CR> 

" around function
" xmap af <Plug>(coc-funcobj-a)
" omap af <Plug>(coc-funcobj-a)

" Show more like under cursor
map *   <Plug>(asterisk-*)
map #   <Plug>(asterisk-#)
map g*  <Plug>(asterisk-g*)
map g#  <Plug>(asterisk-g#)
map z*  <Plug>(asterisk-z*)
map gz* <Plug>(asterisk-gz*)    
map z#  <Plug>(asterisk-z#)
map gz# <Plug>(asterisk-gz#)

" Bspwm
" noremap <silent> <A-h> :BspwmNavigateWest<cr>
" noremap <silent> <A-j> :BspwmNavigateSouth<cr>
" noremap <silent> <A-k> :BspwmNavigateNorth<cr>
" noremap <silent> <A-l> :BspwmNavigateEast<cr>

" Switch CWD to the directory of the open buffer
map <leader>cd :cd %:p:h<cr>:pwd<cr>  

" Prevent x from overriding what's in the clipboard.
noremap x "_x
noremap X "_x

" Change text without putting the text into register,
nnoremap c "_c
nnoremap C "_C
nnoremap cc "_cc

" Don't yank whitespace at the beginning of a line
nnoremap Y ^y$

" Prevent selecting and pasting from overwriting what you originally copied.
xnoremap p pgvy

" When text is wrapped, move by terminal rows, not lines, unless a count is provided
noremap <silent> <expr> j (v:count == 0 ? 'gj' : 'j')
noremap <silent> <expr> k (v:count == 0 ? 'gk' : 'k')

" Movement: Keep under (j/k remap)
vnoremap j <Plug>(easymotion-j)
vnoremap k <Plug>(easymotion-k)

" Movement
vmap j <Plug>(easymotion-j)
vmap k <Plug>(easymotion-k)

" Move a line of text using Ctrl-[jk]
nnoremap <silent> <C-j> :move+<cr>
" nnoremap <silent> <C-k> :move-2<cr>
" xnoremap <silent> <C-k> :move-2<cr>gv
xnoremap <silent> <C-j> :move'>+<cr>gv

" Git
nnoremap <silent> <Leader>gla <cmd>lua require('telescope-config').my_git_commits()<CR>
nnoremap <silent> <Leader>gs <cmd>lua require('telescope-config').my_git_status()<CR>

nnoremap <silent> <C-s> :update<CR>

" TODO: Make this JS only
" Open up a point free function
" nmap gO [(ysa({$i<CR>return <ESC>O

" Toggle paste mode on and off
map <leader>pp :setlocal paste!<cr>

" Quick marker
nnoremap <Leader>m `m

" qq to record, Q to replay
nnoremap Q @q

" copy current file name (relative/absolute) to system clipboard
if has("mac") || has("gui_macvim") || has("gui_mac")
    " relative path  (src/foo.txt)
    nnoremap <leader>cf :let @*=expand("%")<CR>

    " absolute path  (/something/src/foo.txt)
    nnoremap <leader>cF :let @*=expand("%:p")<CR>

    " filename       (foo.txt)
    nnoremap <leader>ct :let @*=expand("%:t")<CR>

    " directory name (/something/src)
    nnoremap <leader>ch :let @*=expand("%:p:h")<CR>
endif

" copy current file name (relative/absolute) to system clipboard (Linux version)
if has("gui_gtk") || has("gui_gtk2") || has("gui_gnome") || has("unix")
    " relative path (src/foo.txt)
    nnoremap <leader>cf :let @+=expand("%")<CR>

    " absolute path (/something/src/foo.txt)
    nnoremap <leader>cF :let @+=expand("%:p")<CR>

    " filename (foo.txt)
    nnoremap <leader>ct :let @+=expand("%:t")<CR>

    " directory name (/something/src)
    nnoremap <leader>ch :let @+=expand("%:p:h")<CR>
endif

" Popup menu
" inoremap <silent><expr> <C-Space> coc#refresh()


" ============================================================================
"  => Colors and Fonts
" ============================================================================

" set guifont=Cousine_Nerd_Font_Mono:h10

" BUG: This conditional causes color inconsistancies when sourcing a second time
" https://superuser.com/a/748204
" if exists('$TMUX')
"     if has('nvim')
"       set termguicolors
"       let $NVIM_TUI_ENABLE_TRUE_COLOR=1
"     else
"         set term=screen-256color
"     endif
" endif

if (has("termguicolors"))
    set termguicolors
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif

" Ensure 256 color support
set t_Co=256

" Enable syntax highlighting
syntax enable

" Scheme
if filereadable(expand("~/.local/share/nvim/colorscheme.vim"))
  source ${HOME}/.local/share/nvim/colorscheme.vim
else
  colorscheme dracula
endif

hi! Pmenu ctermbg=None ctermfg=None guibg=#111111 guifg=None
hi! SignColumn ctermfg=None ctermbg=None guibg=None
hi! NonText ctermfg=None ctermbg=None guibg=None guifg=None
silent! hi! EndOfBuffer ctermbg=None ctermfg=None guibg=None guifg=None
hi CursorColumn         guibg=None guifg=None

hi SpellBad cterm=underline
hi SpellLocal cterm=underline
hi SpellRare cterm=underline
hi SpellCap cterm=underline 

hi HighlightedYankRegion guifg=none guibg=#413C55 ctermbg=235 ctermfg=170

hi link diffAdded DiffAdd
hi link diffChanged DiffChange
hi link diffRemoved DiffDelete

hi UncoveredLine guifg=#d19a66 guibg=none

" Hide tildas
" NOTE: This does not work wirh the dracula-nvim theme
silent! hi! EndOfBuffer ctermbg=bg ctermfg=bg guibg=bg guifg=bg

" Vertical Split
hi VertSplit guibg=bg guifg=#1d1b26

" hi StatusLineNC cterm=none ctermfg=none ctermbg=none guifg=#00ffff guibg=#00ffff

hi CursorLine           guibg=#2D3239 guifg=None

" Highlight current line
set cursorline


" ============================================================================
"  => Scratch Pad (testing)
" ============================================================================

augroup CursorLineOnlyInActiveWindow
    autocmd!
    autocmd VimEnter,WinEnter,BufWinEnter * setlocal cursorline
    autocmd WinLeave * setlocal nocursorline
augroup END  

augroup TodayFile
    autocmd FileReadPre,BufWritePost ${HOME}/Documents/notes/Today.md execute "silent !gawk -i inplace 'BEGIN {p=1} /Agenda/ {print;system(\"echo; khal list; echo\");p=0} /^-+$/ {p=1} p' %" | edit
augroup END  




nnoremap ,dd <Plug>VimspectorContinue
nnoremap ,db <Plug>VimspectorAddFunctionBreakpoint
nnoremap ,dh <Plug>VimspectorRunToCursor

function! HandleDownKey()
    " if !empty(g:vimspector_session_windows.watches)
    " :call vimspector#StepInto()
    " else
    " :execute "normal \<Plug>(coc-diagnostic-next)"
    " endif
endfunction


" let g:vimspector_enable_mappings = 'HUMAN'
nmap <silent> <leader>t :TestNearest<CR>
let g:ultest_use_pty = 1

" xnoremap <leader>a :<C-u>Telescope coc line_code_actions<CR> 
" nnoremap <leader>a :<C-u>Telescope coc line_code_actions<CR> 

" Reselect visual selection after indenting
vnoremap < <gv
vnoremap > >gv

" Maintain the cursor position when yanking a visual selection
vnoremap y myy`y
vnoremap Y myY`y

" Keep it centered
nnoremap n nzzzv
nnoremap N Nzzzv
nnoremap J mzJ`z

" Open the current file in the default program
nmap <leader>x :!xdg-open %<cr><cr>

" Common configs
nmap <leader>vv :edit ~/.config/nvim/init.vim<cr>
" nmap <leader>vc :edit ~/.config/nvim/coc-settings.json<cr>

" Allow gf to open non-existent files
map gf :edit <cfile><cr>


" function! GoGoyo()
"     if !empty(g:vimspector_session_windows.watches)
"         :call vimspector#StepInto()
"     else
"         :execute "normal \<Plug>(coc-diagnostic-next)"
"     endif
" endfunction


"let g:goyo_width = 90
"let g:goyo_height = '100%'

" function! s:goyo_enter()
"     let b:quitting = 0
"     let b:quitting_bang = 0
"     autocmd QuitPre <buffer> let b:quitting = 1
"     cabbrev <buffer> q! let b:quitting_bang = 1 <bar> q!
"     if executable('tmux') && strlen($TMUX) && &filetype !=# 'man' && &filetype !=# 'help'
"         silent !tmux set status off
"         silent !tmux list-panes -F '\#F' | grep -q Z || tmux resize-pane -Z
"     endif
"     " :Limelight
" endfunction

" function! s:goyo_leave()
"     " :Limelight!
"     if executable('tmux') && strlen($TMUX)
"         silent !tmux set status on
"         silent !tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z
"     endif
"     " Quit Vim if this is the only remaining buffer
"     if b:quitting && len(filter(range(1, bufnr('$')), 'buflisted(v:val)')) == 1
"         if b:quitting_bang
"             qa!
"         else
"             qa
"         endif
"     endif
" 
"     " HACK: Sourcing the VIMRC to ensure colors dont get borked after exiting Goyo.
"     " This is slow and will not work with changing color schemes.
"     source $MYVIMRC
"     redraw
" endfunction

" augroup Goyo
"     autocmd!
"     autocmd! User GoyoEnter call <SID>goyo_enter()
"     autocmd! User GoyoLeave call <SID>goyo_leave()
" augroup END

" nmap <A-m> :Goyo<CR>
" nmap <A-m> <Plug>(zoom-toggle)

highlight StatusLine   guifg=#2C323D guibg=#2C323D
highlight StatusLineNC guifg=#2C323D guibg=#2C323D
highlight VertSplit cterm=none ctermfg=blue ctermbg=blue guifg=#2C323D guibg=#2C323D

let g:windowswap_map_keys = 0 "prevent default bindings

function! DoSwapLeft()
    call WindowSwap#MarkWindowSwap() 
    wincmd h 
    call WindowSwap#DoWindowSwap()
endfunction

function! DoSwapDown()
    call WindowSwap#MarkWindowSwap() 
    wincmd j
    call WindowSwap#DoWindowSwap()
endfunction

function! DoSwapUp()
    call WindowSwap#MarkWindowSwap() 
    wincmd k
    call WindowSwap#DoWindowSwap()
endfunction

function! DoSwapRight()
    call WindowSwap#MarkWindowSwap() 
    wincmd l
    call WindowSwap#DoWindowSwap()
endfunction

nnoremap <leader>wh :call DoSwapLeft()<CR>
nnoremap <leader>wj :call DoSwapDown()<CR>
nnoremap <leader>wk :call DoSwapUp()<CR>
nnoremap <leader>wl :call DoSwapRight()<CR>

nnoremap <A-Down> :tabnext<CR>
nnoremap <A-Up> :tabprevious<CR>

map <A-x> :confirm q<CR>

" Add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" Use compact syntax for prettified multi-line comments
let g:NERDCompactSexyComs = 1

" Align line-wise comment delimiters flush left instead of following code indenta  tion
let g:NERDDefaultAlign = 'left'

" Allow commenting and inverting empty lines (useful when commenting a region)
let g:NERDCommentEmptyLines = 1

" Enable trimming of trailing whitespace when uncommenting
let g:NERDTrimTrailingWhitespace = 1

" Enable NERDCommenterToggle to check all selected lines is commented or not
let g:NERDToggleCheckAllLines = 1

" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" nnoremap <silent> <leader>      :<c-u>WhichKey '<Space>'<CR>
" nnoremap <silent> <localleader> :<c-u>WhichKey  ','<CR>
"
" By default timeoutlen is 1000 ms
set timeoutlen=500

" Hooking up the ReScript autocomplete function
set omnifunc=rescript#Complete

" When preview is enabled, omnicomplete will display ad

" information for a selected item
set completeopt+=preview

nnoremap <Leader>gb :<C-u>call gitblame#echo()<CR>
" au BufNewFile ~/documents/notes/diary/*.md : silent 0r !~/.local/share/nvim/bin/generate-vimwiki-diary-template '%'

let g:floaterm_width=120

lua << EOF
-- Global Utils

-- Keyboard Mapping
function map(mode, lhs, rhs, opts)
    local options = { noremap = true }

    if opts then
        options = vim.tbl_extend("force", options, opts)
    end

    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

EOF
