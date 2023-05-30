-- All plugins have lazy=true by default,to load a plugin on startup just lazy=false
-- List of all default plugins & their definitions
local default_plugins = {

  "nvim-lua/plenary.nvim",

  -- nvchad plugins
  { "NvChad/extensions", branch = "v2.0" },

  {
    "NvChad/base46",
    branch = "v2.0",
    build = function()
      require("base46").load_all_highlights()
    end,
  },

  {
    "NvChad/ui",
    branch = "v2.0",
    lazy = false,
    config = function()
      require "nvchad_ui"
    end,
  },

  {
    "NvChad/nvterm",
    lazy = false,
    init = function()
      require("core.utils").load_mappings "nvterm"
    end,
    config = function(_, opts)
      require "base46.term"
      require("nvterm").setup(opts)
    end,
  },

  {
    "kylechui/nvim-surround",
    lazy = false,
    -- tag = "*",
    config = function()
      -- require("plugins.configs.")
    end,
  },

  {
    "ThePrimeagen/git-worktree.nvim",
    lazy = false,
    config = function()
      require "plugins.configs.git-worktree"
    end,
    requires = {
      "folke/which-key.nvim",
      "plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
  },

  {
    "ray-x/lsp_signature.nvim",
    lazy = false,
  },

  {
    "NvChad/nvim-colorizer.lua",
    init = function()
      require("core.utils").lazy_load "nvim-colorizer.lua"
    end,
    config = function(_, opts)
      require("colorizer").setup(opts)

      -- execute colorizer as soon as possible
      vim.defer_fn(function()
        require("colorizer").attach_to_buffer(0)
      end, 0)
    end,
  },

  {
    "pwntester/octo.nvim",
    lazy = false,
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "kyazdani42/nvim-web-devicons",
    },
    config = function()
      require "plugins.configs.octo"
    end,
  },

  {
    "nvim-tree/nvim-web-devicons",
    opts = function()
      return { override = require("nvchad_ui.icons").devicons }
    end,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "devicons")
      require("nvim-web-devicons").setup(opts)
    end,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    init = function()
      require("core.utils").lazy_load "indent-blankline.nvim"
    end,
    opts = function()
      return require("plugins.configs.others").blankline
    end,
    config = function(_, opts)
      require("core.utils").load_mappings "blankline"
      dofile(vim.g.base46_cache .. "blankline")
      require("indent_blankline").setup(opts)
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    init = function()
      require("core.utils").lazy_load "nvim-treesitter"
    end,
    cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
    build = ":TSUpdate",
    opts = function()
      return require "plugins.configs.treesitter"
    end,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "syntax")
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- git stuff
  {
    "lewis6991/gitsigns.nvim",
    ft = { "gitcommit", "diff" },
    init = function()
      -- load gitsigns only when a git file is opened
      vim.api.nvim_create_autocmd({ "BufRead" }, {
        group = vim.api.nvim_create_augroup("GitSignsLazyLoad", { clear = true }),
        callback = function()
          vim.fn.system("git -C " .. '"' .. vim.fn.expand "%:p:h" .. '"' .. " rev-parse")
          if vim.v.shell_error == 0 then
            vim.api.nvim_del_augroup_by_name "GitSignsLazyLoad"
            vim.schedule(function()
              require("lazy").load { plugins = { "gitsigns.nvim" } }
            end)
          end
        end,
      })
    end,
    opts = function()
      return require("plugins.configs.others").gitsigns
    end,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "git")
      require("gitsigns").setup(opts)
    end,
  },

  -- lsp stuff
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUninstall", "MasonUninstallAll", "MasonLog" },
    opts = function()
      return require "plugins.configs.mason"
    end,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "mason")
      require("mason").setup(opts)

      -- custom nvchad cmd to install all mason binaries listed
      vim.api.nvim_create_user_command("MasonInstallAll", function()
        vim.cmd("MasonInstall " .. table.concat(opts.ensure_installed, " "))
      end, {})

      vim.g.mason_binaries_list = opts.ensure_installed
    end,
  },

  {
    "neovim/nvim-lspconfig",
    init = function()
      require("core.utils").lazy_load "nvim-lspconfig"
    end,
    config = function()
      require "plugins.configs.lspconfig"
    end,
  },

  -- load luasnips + cmp related in insert mode only
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      {
        -- snippet plugin
        "L3MON4D3/LuaSnip",
        dependencies = "rafamadriz/friendly-snippets",
        opts = { history = true, updateevents = "TextChanged,TextChangedI" },
        config = function(_, opts)
          require("plugins.configs.others").luasnip(opts)
        end,
      },

      -- autopairing of (){}[] etc
      {
        "windwp/nvim-autopairs",
        opts = {
          fast_wrap = {},
          disable_filetype = { "TelescopePrompt", "vim" },
        },
        config = function(_, opts)
          require("nvim-autopairs").setup(opts)

          -- setup cmp for autopairs
          local cmp_autopairs = require "nvim-autopairs.completion.cmp"
          require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end,
      },

      -- cmp sources plugins
      {
        "saadparwaiz1/cmp_luasnip",
        "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
      },
    },
    opts = function()
      return require "plugins.configs.cmp"
    end,
    config = function(_, opts)
      require("cmp").setup(opts)
    end,
  },

  {
    "numToStr/Comment.nvim",
    keys = { "gcc", "gbc" },
    init = function()
      require("core.utils").load_mappings "comment"
    end,
    config = function()
      require("Comment").setup()
    end,
  },

  -- file managing , picker etc
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    init = function()
      require("core.utils").load_mappings "nvimtree"
    end,
    opts = function()
      return require "plugins.configs.nvimtree"
    end,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "nvimtree")
      require("nvim-tree").setup(opts)
      vim.g.nvimtree_side = opts.view.side
    end,
  },

  {
    "voldikss/vim-floaterm",
    lazy = false,
  },

  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    init = function()
      require("core.utils").load_mappings "telescope"
    end,
    opts = function()
      return require "plugins.configs.telescope"
    end,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "telescope")
      local telescope = require "telescope"
      telescope.setup(opts)

      -- load extensions
      for _, ext in ipairs(opts.extensions_list) do
        telescope.load_extension(ext)
      end
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    requires = { "nvim-tree/nvim-web-devicons", opt = true },
    lazy = false,
    config = function()
      require "plugins.configs.lualine"
    end,
  },

  {
    "rmagatti/auto-session",
    lazy = false,
    config = function()
      require("auto-session").setup {
        log_level = "error",
        auto_session_suppress_dirs = { "~/", "~/downloads", "/" },
      }
    end,
  },

  { lazy = false, "tpope/vim-eunuch" },
  { lazy = false, "nelstrom/vim-visual-star-search" },
  { lazy = false, "machakann/vim-highlightedyank" },

  --expand region (+/-)
  { lazy = false, "terryma/vim-expand-region" },

  {
    "phaazon/hop.nvim",
    lazy = false,
    init = function()
      require "plugins.configs.hop"
    end,
  },

  {
    "folke/zen-mode.nvim",
    lazy = false,
    config = function()
      require "plugins.configs.zen-mode"
    end,
  },

  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    lazy = false,
    event = "InsertEnter",
    init = function()
      require "plugins.configs.copilot"
    end,
  },

  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    lazy = false,
    config = function()
      require("nvim-treesitter.configs").setup {
        context_commentstring = {
          enable = true,
        },
      }
    end,
  },
  {
    "zbirenbaum/copilot-cmp",
    after = { "copilot.lua" },
    lazy = false,
    config = function()
      require("copilot_cmp").setup {}
    end,
  },

  --Swap windows without ruining your layout!
  {
    "wesQ3/vim-windowswap",
    lazy = false,
    config = function()
      vim.cmd [[
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
        ]]
    end,
  },

  {
    "windwp/nvim-ts-autotag",
    lazy = false,
    config = function()
      require "plugins.configs.ts-autotag"
    end,
  },
  {
    "sindrets/winshift.nvim",
    lazy = false,
    config = function()
      require("winshift").setup {
        keymaps = {
          disable_defaults = true, -- Disable the default keymaps
        },
      }
    end,
  },
  {
    "windwp/nvim-spectre",
    lazy = false,
    requires = "nvim-lua/plenary.nvim",
    config = function()
      require("spectre").setup()
    end,
  },
  {
    "sindrets/diffview.nvim",
    requires = "nvim-lua/plenary.nvim",
    lazy = false,
    config = function()
      require "plugins.configs.diffview"
    end,
  },
  {
    "edluffy/specs.nvim",

    lazy = false,
    config = function()
      -- require('plugins.configs.specs')
      require("specs").setup {
        show_jumps = true,
        min_jump = 30,
        popup = {
          delay_ms = 0, -- delay before popup displays
          inc_ms = 10, -- time increments used for fade/resize effects
          blend = 10, -- starting blend, between 0-100 (fully transparent), see :h winblend
          width = 10,
          winhl = "PMenu",
          fader = require("specs").linear_fader,
          resizer = require("specs").shrink_resizer,
        },
        ignore_filetypes = {},
        ignore_buftypes = {
          nofile = true,
        },
      }
    end,
  },

  {
    "sQVe/sort.nvim",
    lazy = false,
    config = function()
      require("sort").setup {
        delimiters = {
          ",",
          "|",
          ";",
          ":",
          "s", -- Space
          "t", -- Tab
        },
      }
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    lazy = false,
    requires = "nvim-treesitter/nvim-treesitter",
    config = function()
      require "plugins.configs.treesitter-context"
    end,
  },
  {
    "rmagatti/goto-preview",
    lazy = false,
    config = function()
      require "plugins.configs.goto-preview"
    end,
    requires = { "folke/which-key.nvim" },
  },
  {
    "haringsrob/nvim_context_vt",
    lazy = false,
    requires = "nvim-treesitter/nvim-treesitter",
    config = function()
      require "plugins.configs.nvim_context_vt"
    end,
  },

  -- incremental search improved
  { "haya14busa/is.vim", lazy = false },

  {
    "bennypowers/nvim-regexplainer",
    lazy = false,
    config = function()
      require("regexplainer").setup {
        mode = "narrative",
        auto = true,
        -- filetypes (i.e. extensions) in which to run the autocommand
        filetypes = {
          "html",
          "js",
          "cjs",
          "mjs",
          "ts",
          "jsx",
          "tsx",
          "cjsx",
          "mjsx",
        },
        -- Whether to log debug messages
        debug = false,
        -- 'split', 'popup'
        display = "popup",
        mappings = {
          toggle = "gR",
          -- examples, not defaults:
          -- show = 'gS',
          -- hide = 'gH',
          -- show_split = 'gP',
          -- show_popup = 'gU',
        },
        narrative = {
          separator = "\n",
        },
      }
    end,
    requires = {
      "nvim-treesitter/nvim-treesitter",
      "MunifTanjim/nui.nvim",
    },
  },

  {
    "z0mbix/vim-shfmt",
    lazy = false,
    config = function()
      vim.g.shfmt_extra_args = '-i 2'
      vim.g.shfmt_fmt_on_save = 0
    end
  },

  -- Only load whichkey after all the gui
  {
    "folke/which-key.nvim",
    keys = { "<leader>", '"', "'", "`", "c", "v" },
    init = function()
      require("core.utils").load_mappings "whichkey"
      require "plugins.configs.sgpt"
    end,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "whichkey")
      require("which-key").setup(opts)
    end,
  },
}

local config = require("core.utils").load_config()

if #config.plugins > 0 then
  table.insert(default_plugins, { import = config.plugins })
end

require("lazy").setup(default_plugins, config.lazy_nvim)
