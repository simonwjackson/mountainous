vim.cmd([[
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

]])


require('packer').startup(function(use)
  use {
    "folke/which-key.nvim",
    config = function() require('plugins/which-key') end
  }

  use {
    'neovim/nvim-lspconfig',
    config = function() require('plugins/lspconfig') end,
    requires = { 'folke/which-key.nvim', opt = true }
  }

  use {
    'nvim-lualine/lualine.nvim',
    config = function() require('plugins/lualine') end,
    requires = { 'kyazdani42/nvim-web-devicons', opt = true }
  }

  use {
    "L3MON4D3/LuaSnip",
    tag = "v<CurrentMajor>.*"
  }

  use {
    'rmagatti/goto-preview',
    config = function() require('plugins/goto-preview') end,
    requires = { "folke/which-key.nvim" }
  }

  -- editorconfig support in vim
  use "editorconfig/editorconfig-vim"

  -- incremental search improved
  use "haya14busa/is.vim"

  -- use {
  --   "folke/noice.nvim",
  --   config = function()
  --     require('plugins/noice')
  --   end,
  --   requires = {
  --     -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
  --     "MunifTanjim/nui.nvim",
  --     -- OPTIONAL:
  --     --   `nvim-notify` is only needed, if you want to use the notification view.
  --     --   If not available, we use `mini` as the fallback
  --     "rcarriga/nvim-notify",
  --   }
  -- }

  use {
    'phaazon/hop.nvim',
    branch = 'v2', -- optional but strongly recommended
    config = function()
      require('plugins/hop')
    end
  }

  use {
    "folke/twilight.nvim",
    config = function()
      require("plugins/twilight")
    end
  }

  use {
    "folke/zen-mode.nvim",
    config = function()
      require("plugins/zen-mode")
    end
  }

  use {
    "stevearc/dressing.nvim",
    config = function()
      require("plugins/dressing")
    end
  }

  use {
    "folke/trouble.nvim",
    requires = "kyazdani42/nvim-web-devicons",
    config = function()
      require("plugins/trouble")
    end
  }

  use {
    "folke/todo-comments.nvim",
    requires = "nvim-lua/plenary.nvim",
    config = function()
      require("plugins/todo-comments")
    end
  }

  use {
    "rest-nvim/rest.nvim",
    requires = { "nvim-lua/plenary.nvim" },
    config = function()
      require("plugins/rest")
    end
  }

  use {
    "kevinhwang91/nvim-hlslens",
    requires = "petertriho/nvim-scrollbar",
    config = function()
      require("scrollbar.handlers.search").setup({
        -- If you want to leave only search marks and disable virtual text:
        override_lens = function()
        end,
      })
    end,
  }

  use {
    'lewis6991/gitsigns.nvim',
    requires = "petertriho/nvim-scrollbar",
    config = function()
      require('plugins/gitsigns')
      require("scrollbar.handlers.gitsigns").setup()
    end
  }

  use {
    'vimwiki/vimwiki',
    config = function()
      require('plugins/vimwiki')
    end
  }

  -- Proper project management in vim.
  -- INFO: dificult (impossible to install?) in packer
  use {
    'tools-life/taskwiki',
    requires = 'vimwiki/vimwiki',
  }

  ------------------------------------------------------
  -- - Themes
  ------------------------------------------------------

  use 'flrnprz/plastic.vim'
  use 'lifepillar/vim-solarized8'
  use {
    'Mofiqul/dracula.nvim',
    config = function() vim.cmd([[ colorscheme dracula ]]) end,
  }
  ------------------------------------------------------
  -- - Language Support
  ------------------------------------------------------


  use "peterhoeg/vim-qml"
  use 'nvim-treesitter/playground'

  --Rofi
  use 'Fymyte/rasi.vim'

  use 'nikolvs/vim-sunbather'

  --MDX
  use 'jxnblk/vim-mdx-js'

  --Seamless navigation between tmux panes and vim splits
  use 'christoomey/vim-tmux-navigator'

  --Vim sugar for the UNIX shell commands that need it the most
  use 'tpope/vim-eunuch'

  ------------------------------------------------------------------------------
  -- - Extras
  ------------------------------------------------------------------------------

  --Adds file type icons to Vim plugins
  use 'ryanoasis/vim-devicons'

  --Improved * motions
  use {
    'haya14busa/vim-asterisk',
    config = function()
      vim.g.asterisk_no_default_mappings = 1
      vim.cmd([[
        let g:asterisk#keeppos = 1

        " Show more like under cursor
        map *   <Plug>(asterisk-*)
        map #   <Plug>(asterisk-#)
        map g*  <Plug>(asterisk-g*)
        map g#  <Plug>(asterisk-g#)
        map z*  <Plug>(asterisk-z*)
        map gz* <Plug>(asterisk-gz*)
        map z#  <Plug>(asterisk-z#)
        map gz# <Plug>(asterisk-gz#)
      ]])
    end
  }

  --Briefly highlight which text was yanked.
  use 'machakann/vim-highlightedyank'

  --Modify * to also work with visual selections.
  use 'nelstrom/vim-visual-star-search'


  --FocusGained and FocusLost for vim inside Tmux
  --This is a plugin for Vim to dim inactive windows.
  use 'tmux-plugins/vim-tmux-focus-events'

  --An eye friendly plugin that fades your inactive buffers and preserves your syntax highlighting!
  --use 'TaDaa/vimade'

  --Taskwarrior in VIM
  --use 'farseer90718/vim-taskwarrior'

  --Zettelkasten for VIM
  use 'michal-h21/vim-zettel'

  use 'nvim-lua/popup.nvim'

  --INFO: This is a generic/global plugin for lua. Please delete with caution.
  use 'nvim-lua/plenary.nvim'

  --Icons
  use 'kyazdani42/nvim-web-devicons'

  --Auto Sessions
  --use 'rmagatti/auto-session'
  --use 'rmagatti/session-lens'

  --LazyGit
  use {
    'kdheepak/lazygit.nvim',
    requires = 'nvim-telescope/telescope.nvim',
  }

  --expand region (+/-)
  use 'terryma/vim-expand-region'

  --Ultisnips: Text Expansion
  use 'SirVer/ultisnips'

  --A multi-language debugging system for Vim
  use 'puremourning/vimspector'

  --VIM Test
  use 'vim-test/vim-test'
  --use 'rcarriga/vim-ultest', { 'do': ':UpdateRemoteuseins' }

  use 'tpope/vim-obsession'

  use 'camgraff/telescope-tmux.nvim'
  use 'RyanMillerC/better-vim-tmux-resizer'

  --Swap windows without ruining your layout!
  use {
    'wesQ3/vim-windowswap',
    config = function()
      vim.cmd([[
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
      ]])
    end
  }

  use {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.0',
    config = function()
      require('plugins/telescope')
    end,
    requires = {
      'nvim-lua/plenary.nvim'
    }
  }

  -- use {
  --   "zbirenbaum/copilot.lua",
  --   config = function()
  --     vim.defer_fn(function()
  --     end, 100)
  --   end
  -- }

  use {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("plugins/copilot")
    end,
  }

  use {
    "zbirenbaum/copilot-cmp",
    after = { "copilot.lua" },
    config = function()
      require("copilot_cmp").setup({})
    end
  }

  -- TODO: Depends on cmp
  use {
    "onsails/lspkind.nvim",
    config = function()
      require("plugins/lspkind")
    end
  }

  use({
    "ThePrimeagen/git-worktree.nvim",
    config = function()
      require('plugins/git-worktree')
    end,
    requires = {
      "folke/which-key.nvim",
      "plenary.nvim",
      "nvim-telescope/telescope.nvim"
    }
  })

  use({
    "lmburns/lf.nvim",
    config = function()
      require('plugins/lf')
    end,
    requires = {
      "folke/which-key.nvim",
      "nvim-lua/plenary.nvim",
      "akinsho/toggleterm.nvim"
    }
  })

  -- use {
  --   'Equilibris/nx.nvim',
  --   requires = {
  --     'nvim-telescope/telescope.nvim',
  --   },
  --   config = function()
  --     require('plugins/nx')
  --   end
  -- }

  -- use 'glacambre/firenvim', { 'do': { _ -> firenvim#install(0) } }

  use 'MunifTanjim/eslint.nvim'

  -- TODO: Disabled for now due to performance issues
  -- use 'https://git.sr.ht/~whynothugo/lsp_lines.nvim'

  use {
    'JoosepAlviste/nvim-ts-context-commentstring',
    config = function()
      require('nvim-treesitter.configs').setup({
        context_commentstring = {
          enable = true
        }
      })
    end
  }

  use {
    'numToStr/Comment.nvim',
    config = function()
      require('plugins/comment')
    end
  }

  use {
    "LudoPinelli/comment-box.nvim",
    config = function()
      require('plugins/comment-box')
    end
  }

  use {
    'pwntester/octo.nvim',
    requires = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'kyazdani42/nvim-web-devicons',
    },
    config = function()
      require('plugins/octo')
    end
  }

  -- Interactive theme creator
  use 'rktjmp/lush.nvim'

  use {
    'nvim-treesitter/nvim-treesitter',
    config = function()
      require('plugins/treesitter')
    end,
    run = function()
      local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
      ts_update()
    end,
  }

  use({
    "kylechui/nvim-surround",
    tag = "*",
    config = function()
      require("plugins/coverage")
    end
  })

  --  Git Blame plugin for Neovim written in Lua
  use 'f-person/git-blame.nvim'

  -- Displays coverage information in the sign column.
  use({
    "andythigpen/nvim-coverage",
    requires = "nvim-lua/plenary.nvim",
    config = function() require("plugins/nvim-coverage") end,
  })

  use "ray-x/lsp_signature.nvim"

  -- NOTE: Built into nvim v0.9
  -- set splitkeep=screen
  use {
    "luukvbaal/stabilize.nvim",
    config = function()
      require("stabilize").setup({
        force = true,    -- stabilize window even when current cursor position will be hidden behind new window
        forcemark = nil, -- set context mark to register on force event which can be jumped to with '<forcemark>
        ignore = {
          -- do not manage windows matching these file/buftypes
          filetype = { "help", "list", "Trouble" },
          buftype = { "terminal", "quickfix", "loclist" }
        },
        nested = nil -- comma-separated list of autocmds that wil trigger the plugins window restore function
      })
    end
  }

  use {
    'sindrets/winshift.nvim',
    config = function()
      require('winshift').setup({
        keymaps = {
          disable_defaults = true, -- Disable the default keymaps
        }
      })
    end,
  }

  use {
    'rmagatti/auto-session',
    config = function()
      require("auto-session").setup {
        log_level = "error",
      }
      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
    end
  }

  use { 'bennypowers/nvim-regexplainer',
    config = function()
      require 'regexplainer'.setup({
        mode = 'narrative',
        auto = true,
        -- filetypes (i.e. extensions) in which to run the autocommand
        filetypes = {
          'html',
          'js',
          'cjs',
          'mjs',
          'ts',
          'jsx',
          'tsx',
          'cjsx',
          'mjsx',
        },
        -- Whether to log debug messages
        debug = false,
        -- 'split', 'popup'
        display = 'popup',
        mappings = {
          toggle = 'gR',
          -- examples, not defaults:
          -- show = 'gS',
          -- hide = 'gH',
          -- show_split = 'gP',
          -- show_popup = 'gU',
        },
        narrative = {
          separator = '\n',
        },
      })
    end,
    requires = {
      'nvim-treesitter/nvim-treesitter',
      'MunifTanjim/nui.nvim',
    }
  }

  -- INFO: Not sure if I want to use this
  -- use {
  --   'anuvyklack/pretty-fold.nvim',
  --   config = function()
  --     require('plugins/pretty-fold')
  --   end
  -- }

  use({
    'sQVe/sort.nvim',
    config = function()
      require("sort").setup({
        delimiters = {
          ',',
          '|',
          ';',
          ':',
          's', -- Space
          't'  -- Tab
        }
      })
    end
  })

  use {
    'nvim-treesitter/nvim-treesitter-context',
    requires = 'nvim-treesitter/nvim-treesitter',
    config = function()
      require('plugins/treesitter-context')
    end
  }

  use {
    'haringsrob/nvim_context_vt',
    requires = 'nvim-treesitter/nvim-treesitter',
    config = function()
      require('plugins/nvim_context_vt')
    end
  }

  use {
    'monaqa/dial.nvim',
    config = function()
      require('plugins/dial')
    end
  }

  use {
    'windwp/nvim-ts-autotag',
    config = function()
      require('plugins/ts-autotag')
    end
  }

  use {
    'edluffy/specs.nvim',
    config = function()
      -- require('plugins/specs')
      require('specs').setup {
        show_jumps       = true,
        min_jump         = 30,
        popup            = {
          delay_ms = 0, -- delay before popup displays
          inc_ms = 10,  -- time increments used for fade/resize effects
          blend = 10,   -- starting blend, between 0-100 (fully transparent), see :h winblend
          width = 10,
          winhl = "PMenu",
          fader = require('specs').linear_fader,
          resizer = require('specs').shrink_resizer
        },
        ignore_filetypes = {},
        ignore_buftypes  = {
          nofile = true,
        },
      }
    end
  }

  use {
    "petertriho/nvim-scrollbar",
    config = function()
      require("plugins/scrollbar")
    end
  }

  use({
    "ziontee113/color-picker.nvim",
    config = function()
      require("plugins/color-picker")
    end,
  })

  use {
    'sindrets/diffview.nvim',
    requires = 'nvim-lua/plenary.nvim',
    config = function()
      require('plugins/diffview')
    end
  }

  use {
    'cljoly/telescope-repo.nvim',
    config = function()
      require("telescope").setup {
        extensions = {
          repo = {
            list = {
              fd_opts = {
                "--no-ignore-vcs",
              },
              search_dirs = {
                "~/code",
              },
            },
          },
        },
      }

      require("telescope").load_extension "repo"
    end
  }

  use {
    'windwp/nvim-spectre',
    requires = 'nvim-lua/plenary.nvim',
    config = function()
      require('spectre').setup()
    end
  }

  use({
    "jackMort/ChatGPT.nvim",
    config = function()
      require("chatgpt").setup({
        -- welcome_message = WELCOME_MESSAGE, -- set to "" if you don't like the fancy godot robot
        loading_text = "loading",
        question_sign = "", -- you can use emoji if you want e.g. 🙂
        answer_sign = "ﮧ", -- 🤖
        max_line_length = 120,
        yank_register = "+",
        chat_layout = {
          relative = "editor",
          position = "50%",
          size = {
            height = "80%",
            width = "80%",
          },
        },
        settings_window = {
          border = {
            style = "rounded",
            text = {
              top = " Settings ",
            },
          },
        },
        chat_window = {
          filetype = "chatgpt",
          border = {
            highlight = "FloatBorder",
            style = "rounded",
            text = {
              top = " ChatGPT ",
            },
          },
        },
        chat_input = {
          prompt = "  ",
          border = {
            highlight = "FloatBorder",
            style = "rounded",
            text = {
              top_align = "center",
              top = " Prompt ",
            },
          },
        },
        openai_params = {
          model = "text-davinci-003",
          frequency_penalty = 0,
          presence_penalty = 0,
          max_tokens = 300,
          temperature = 0,
          top_p = 1,
          n = 1,
        },
        openai_edit_params = {
          model = "code-davinci-edit-001",
          temperature = 0,
          top_p = 1,
          n = 1,
        },
        keymaps = {
          close = { "<C-c>", "<Esc>" },
          yank_last = "<C-y>",
          scroll_up = "<C-u>",
          scroll_down = "<C-d>",
          toggle_settings = "<C-o>",
          new_session = "<C-n>",
          cycle_windows = "<Tab>",
        },
      })
    end,
    requires = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim"
    }
  })
end);

vim.cmd([[
  highlight FloatBorder guifg=#000000 guibg=none
  " set completeopt=menu,menuone,noselect
]])

vim.diagnostic.config({
  virtual_text = false,
  virtual_lines = {
    only_current_line = true
  }
})

vim.cmd([[
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


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

]])

-- Better vertical split fill character
vim.opt.fillchars = "vert:█"

-- ...?
vim.opt.hidden = false

-- Default encoding
vim.opt.encoding = "utf-8"

-- Be smart when using tabs ;)
vim.opt.smarttab = true

-- Use spaces for tab key
vim.opt.expandtab = true

-- set autoindent
vim.opt.smartindent = true
vim.opt.wrap = true

-- Use Unix as the standard file type
vim.opt.ffs = "unix,dos,mac"

-- Share clipboard with OS
vim.opt.clipboard = "unnamedplus"

vim.cmd([[

" Linebreak on 500 characters
set linebreak
set tw=500

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
    elseif (&ft=='sh')
      call Preserve("normal gg=G")
    elseif (&ft=='vim')
      " do nothing
    elseif (&ft=='vimwiki')
      " do nothing
    elseif (&ft=='markdown')
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

" ============================================================================
" => Plugin configuration
" ============================================================================

]])


-- TMUX / VIM integration

local wk = require("which-key")

wk.register({
      ["<A-h>"] = { '<cmd>TmuxNavigateLeft<cr>', "Navigate left" },
      ["<A-j>"] = { '<cmd>TmuxNavigateDown<cr>', "Navigate down" },
      ["<A-k>"] = { '<cmd>TmuxNavigateUp<cr>', "Navigate up" },
      ["<A-l>"] = { '<cmd>TmuxNavigateRight<cr>', "Navigate right" },
      ["<A-S-Left>"] = { '<cmd>TmuxResizeLeft<cr>', "Resize left" },
      ["<A-S-C-Left>"] = { '<cmd>TmuxResizeLeft<cr>', "Resize left" },
      ["<A-S-Down>"] = { '<cmd>TmuxResizeDown<cr>', "Resize down" },
      ["<A-S-C-Down>"] = { '<cmd>TmuxResizeDown<cr>', "Resize down" },
      ["<A-S-Up>"] = { '<cmd>TmuxResizeUp<cr>', "Resize up" },
      ["<A-S-C-Up>"] = { '<cmd>TmuxResizeUp<cr>', "Resize up" },
      ["<A-S-Right>"] = { '<cmd>TmuxResizeRight<cr>', "Resize right" },
      ["<A-S-C-Right>"] = { '<cmd>TmuxResizeRight<cr>', "Resize right" },
}, { noremap = true })

vim.g.tmux_navigator_no_mappings = 1
-- Disable tmux navigator when zooming the Vim pane
vim.g.tmux_navigator_disable_when_zoomed = 1
vim.g.tmux_resizer_no_mappings = 1
vim.g.tmux_resizer_resize_count = 5
vim.g.tmux_resizer_vertical_resize_count = 10




vim.cmd([[

" ----------------------------------------------------------------------------
"  - Zettelkasten
" ----------------------------------------------------------------------------

let g:zettel_fzf_command = 'rg'



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

]])


wk.register({
  -- Finding code
      ["<F1>"] = { '<cmd>Spectre<cr>', "Find and Replace (Global)" },
      ["<F2>"] = { '<cmd>Telescope live_grep<cr>', "Grep Project" },
      ["<F3>"] = { '<cmd>TodoTelescope<cr>', "Project Todos" },
      ["<F4>"] = { '<cmd>Telescope keymaps<cr>', "Telescope keymaps" },
  -- Finding Files
      ["<F6>"] = { '<cmd>call LazyGitPopup()<cr>', "Open Lazygit" },
      ['<F8>'] = { "<cmd>lua require('telescope.builtin').buffers()<cr>", "Show open buffers" },
      ['<F10>'] = { "<cmd>Telescope oldfiles<CR><cr>", "Show recent files" },
}, { noremap = true, silent = true })


vim.cmd([[
" ============================================================================
"  - Motions
" ============================================================================

" Switch CWD to the directory of the open buffer
map <leader>cd :cd %:p:h<cr>:pwd<cr>

" When text is wrapped, move by terminal rows, not lines, unless a count is provided
noremap <silent> <expr> j (v:count == 0 ? 'gj' : 'j')
noremap <silent> <expr> k (v:count == 0 ? 'gk' : 'k')


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

colorscheme dracula

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

" Allow gf to open non-existent files
map gf :edit <cfile><cr>



highlight StatusLine   guifg=#2C323D guibg=#2C323D
highlight StatusLineNC guifg=#2C323D guibg=#2C323D
highlight VertSplit cterm=none ctermfg=blue ctermbg=blue guifg=#2C323D guibg=#2C323D


nnoremap <A-Down> :tabnext<CR>
nnoremap <A-Up> :tabprevious<CR>

map <A-x> :confirm q<CR>

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

let g:floaterm_width=120

nnoremap <silent> <C-s> :update<CR>

if has('nvim') && executable('nvr')
  let $GIT_EDITOR = "nvr -cc split --remote-wait +'set bufhidden=wipe'"
endif

]])

-- Global Utils

-- Keyboard Mapping
function map(mode, lhs, rhs, opts)
  local options = { noremap = true }

  if opts then
    options = vim.tbl_extend("force", options, opts)
  end

  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

vim.defer_fn(function()
  vim.cmd [[highlight! NormalFloat guibg=#282a36]]
  vim.cmd [[highlight! FloatBorder guifg=#6272a4 guibg=#282a36]]
end, 1000)
