local overrides = require("custom.configs.overrides")

---@type NvPluginSpec[]
local plugins = {

  -- Override plugin definition options

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- format & linting
      {
        "jose-elias-alvarez/null-ls.nvim",
        config = function()
          require "custom.configs.null-ls"
        end,
      },
    },
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.configs.lspconfig"
    end, -- Override to setup mason-lspconfig
  },

  -- override plugin configs
  {
    "williamboman/mason.nvim",
    opts = overrides.mason
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = overrides.treesitter,
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = overrides.nvimtree,
  },

  -- Install a plugin
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function()
      require("better_escape").setup()
    end,
  },

  {
    ft = "markdown.mdx",
    'jxnblk/vim-mdx-js'
  },

  {
    "folke/todo-comments.nvim",
    requires = "nvim-lua/plenary.nvim",
    lazy = false,
    config = function()
      require "plugins.configs.todo-comments"
    end
  },

  {
    'vimwiki/vimwiki',
    lazy=false,
    init = function()
      vim.cmd([[
        let g:vimwiki_global_ext = 0
        let g:vimwiki_markdown_link_ext = 1
        let g:vimwiki_links_space_char = '-'
        let g:vimwiki_autowriteall = 1
        let g:vimwiki_syntax = 'markdown'
        let g:vimwiki_ext = '.md'
        let g:vimwiki_main = 'README'
        let g:vimwiki_auto_chdir = 1
        let g:vimwiki_folding=''

        " augroup vimwiki
        "     autocmd!
        "     au BufReadPost,BufNewFile *.md*,*.txt,*.tex setlocal autoread
        "     au BufReadPost,BufNewFile *.md*,*.txt,*.tex ScrollbarHide
        "     au BufReadPost,BufNewFile *.md*,*.txt,*.tex Gitsigns detach
        " augroup END

        let notes = {}
        let notes.path = "$HOME/documents/notes"

        " augroup vimwiki_gutter_disable
        "   autocmd!
        "   autocmd FileType vimwiki setlocal signcolumn=no
        "   autocmd FileType vimwiki setlocal foldcolumn=0
        " augroup END

        let g:vimwiki_list = [notes]
        let g:vimwiki_ext2syntax = {
          \ '.md': 'markdown',
          \ '.markdown': 'markdown',
          \ '.mdown': 'markdown'
          \ }
      ]])
    end
  },

  {
    'tools-life/taskwiki',
    lazy=false,
    -- requires = 'vimwiki/vimwiki',
    -- config = function()
    --   vim.cmd [[
    --     let g:taskwiki_extra_warriors={'H': {'data_location': '~/.local/share/task', 'taskrc_location': '~/.config/task/taskrc'}}
    --   ]]
    -- end
  }
  -- All NvChad plugins are lazy-loaded by default
}

return plugins
