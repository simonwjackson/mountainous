local opt = vim.opt
local g = vim.g
local api = vim.api
local cmd = vim.api.nvim_command

-------------------------------------- globals -----------------------------------------

-- If term is last window. exit cmd === quit
api.nvim_exec([[
  autocmd TermClose * if len(getbufinfo({'buflisted':1})) == 1 && getline(1, '$') == [''] | quit | endif
  autocmd BufLeave * if len(getbufinfo({'buflisted':1})) == 1 && getline(1, '$') == [''] | quit | endif
]], false)

-------------------------------------- options ------------------------------------------
opt.laststatus = 3 -- global statusline
opt.showmode = false

opt.clipboard = "unnamedplus"
opt.cursorline = true

-- Indenting
opt.expandtab = true
opt.shiftwidth = 2
opt.smartindent = true
opt.tabstop = 2
opt.softtabstop = 2

opt.fillchars = { eob = " " }
opt.ignorecase = true
opt.smartcase = true
opt.mouse = "a"

-- Numbers
opt.number = false
opt.numberwidth = 2
opt.ruler = false

-- disable nvim intro
opt.shortmess:append("sI")

opt.signcolumn = "yes"
opt.splitbelow = true
opt.splitright = true
opt.termguicolors = true
opt.timeoutlen = 400
opt.undofile = true
opt.scrollback = 100000

opt.showtabline = 0

-- interval for writing swap file to disk, also used by gitsigns
opt.updatetime = 250

-- go to previous/next line with h,l,left arrow and right arrow
-- when cursor reaches end/beginning of line
opt.whichwrap:append("<>[]hl")

g.mapleader = " "

--- CUSTOM ---
opt.splitkeep = "screen" -- keeps the same screen screen lines in all split windows

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end

-------------------------------------- Custom Functions -----------------------------------------

function OpenLfInFloaterm()
	local path = vim.fn.shellescape(vim.fn.fnamemodify(vim.fn.expand("%:p"), ":!"))

	vim.cmd(
		"FloatermNew --title=Files --name=files --height=0.75 --width=0.75 --wintype=float $SHELL -c 'lf "
			.. path
			.. "'"
	)
end

-------------------------------------- Custom Functions -----------------------------------------

vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct

require("lazy").setup({
	{
		"folke/which-key.nvim",
		init = function()
			local wk = require("which-key")

      function _G.my_lazygit()
          cmd("tabnew")
          cmd("LualineRenameTab LazyGit")
          cmd("terminal nvr -c 'terminal lazygit' -c 'startinsert' '+let g:auto_session_enabled = v:false'")
      end

			wk.register({
				["<A-s>"] = {
					"<C-\\><C-n>:silent! !tmux choose-tree<cr>",
					"show tmux sessions",
					opts = { nowait = true },
				},
			}, { mode = "t" })

			wk.register({
				["<leader>gg"] = { _G.my_lazygit, "Open lazygit", opts = { nowait = true } },
				["<A-s>"] = { ":silent! !tmux choose-tree<cr>", "show tmux sessions", opts = { nowait = true } },
				["<A-1>"] = { ":silent! tabn 1<cr>", "Go to tab 1", opts = { nowait = true } },
				["<A-2>"] = { ":silent! tabn 2<cr>", "Go to tab 2", opts = { nowait = true } },
				["<A-3>"] = { ":silent! tabn 3<cr>", "Go to tab 3", opts = { nowait = true } },
				["<A-4>"] = { ":silent! tabn 4<cr>", "Go to tab 4", opts = { nowait = true } },
				["<A-5>"] = { ":silent! tabn 5<cr>", "Go to tab 5", opts = { nowait = true } },
				["<A-6>"] = { ":silent! tabn 6<cr>", "Go to tab 6", opts = { nowait = true } },
				["<A-7>"] = { ":silent! tabn 7<cr>", "Go to tab 7", opts = { nowait = true } },
				["<A-8>"] = { ":silent! tabn 8<cr>", "Go to tab 8", opts = { nowait = true } },
				["<A-9>"] = { ":silent! tabn 9<cr>", "Go to tab 9", opts = { nowait = true } },
			}, { mode = "n" })
			-- See `<cmd> :help vim.lsp.*` for documentation on any of the below functions

			wk.register({
				["gD"] = {
					function()
						vim.lsp.buf.declaration()
					end,
					"LSP declaration",
				},

				["gd"] = {
					function()
						vim.lsp.buf.definition()
					end,
					"LSP definition",
				},

				["K"] = {
					function()
						vim.lsp.buf.hover()
					end,
					"LSP hover",
				},

				--       		-- Navigation through hunks
				["<Down>"] = {
					function()
						if vim.wo.diff then
							return "]c"
						end
						vim.schedule(function()
							require("gitsigns").next_hunk()
						end)
						return "<Ignore>"
					end,
					"Jump to next hunk",
					opts = { expr = true },
				},

				["<Up>"] = {
					function()
						if vim.wo.diff then
							return "[c"
						end
						vim.schedule(function()
							require("gitsigns").prev_hunk()
						end)
						return "<Ignore>"
					end,
					"Jump to prev hunk",
					opts = { expr = true },
				},

				-- Actions
				["<leader>rh"] = {
					function()
						require("gitsigns").reset_hunk()
					end,
					"Reset hunk",
				},

				["<leader>ph"] = {
					function()
						require("gitsigns").preview_hunk()
					end,
					"Preview hunk",
				},

				["<leader>gb"] = {
					function()
						package.loaded.gitsigns.blame_line()
					end,
					"Blame line",
				},

				["<leader>td"] = {
					function()
						require("gitsigns").toggle_deleted()
					end,
					"Toggle deleted",
				},

				-- ["gi"] = {
				-- 	function()
				-- 		vim.lsp.buf.implementation()
				-- 	end,
				-- 	"LSP implementation",
				-- },
				--
				-- ["<leader>ls"] = {
				-- 	function()
				-- 		vim.lsp.buf.signature_help()
				-- 	end,
				-- 	"LSP signature help",
				-- },
				--
				-- ["<leader>D"] = {
				-- 	function()
				-- 		vim.lsp.buf.type_definition()
				-- 	end,
				-- 	"LSP definition type",
				-- },
				--
				-- ["<leader>ra"] = {
				-- 	function()
				-- 		require("nvchad_ui.renamer").open()
				-- 	end,
				-- 	"LSP rename",
				-- },
				--
				-- ["<leader>ca"] = {
				-- 	function()
				-- 		vim.lsp.buf.code_action()
				-- 	end,
				-- 	"LSP code action",
				-- },
				--
				-- ["gr"] = {
				-- 	function()
				-- 		vim.lsp.buf.references()
				-- 	end,
				-- 	"LSP references",
				-- },
				--
				-- ["<leader>f"] = {
				-- 	function()
				-- 		vim.diagnostic.open_float({ border = "rounded" })
				-- 	end,
				-- 	"Floating diagnostic",
				-- },
				--
				["[d"] = {
					function()
						vim.diagnostic.goto_prev({ float = { border = "rounded" } })
					end,
					"Goto prev",
				},

				["]d"] = {
					function()
						vim.diagnostic.goto_next({ float = { border = "rounded" } })
					end,
					"Goto next",
				},

				["<leader>q"] = {
					function()
						vim.diagnostic.setloclist()
					end,
					"Diagnostic setloclist",
				},
			}, { mode = "n" })

			wk.register({
				-- Don't copy the replaced text after pasting in visual mode
				-- https://vim.fandom.com/wiki/Replace_a_word_with_yanked_text#Alternative_mapping_for_paste
				["p"] = { 'p:let @+=@0<CR>:let @"=@0<CR>', "Dont copy replaced text", opts = { silent = true } },
			}, { mode = "x" })

			wk.register({
				["<A-Esc>"] = {
					vim.api.nvim_replace_termcodes("<C-\\><C-N>", true, true, true),
					"Escape terminal mode",
				},
				["<C-Esc>"] = {
					vim.api.nvim_replace_termcodes("<C-\\><C-N>", true, true, true),
					"Escape terminal mode",
				},
				["<A-h>"] = { "<C-\\><C-N><C-w>h", "Window left" },
				["<A-l>"] = { "<C-\\><C-N><C-w>l", "Window right" },
				["<A-j>"] = { "<C-\\><C-N><C-w>j", "Window down" },
				["<A-k>"] = { "<C-\\><C-N><C-w>k", "Window up" },
			}, { mode = "t" })

			wk.register({
				["<Esc>"] = { ":noh <CR>", "Clear highlights" },
				-- switch between windows
				["<A-h>"] = { "<C-w>h", "Window left" },
				["<A-l>"] = { "<C-w>l", "Window right" },
				["<A-j>"] = { "<C-w>j", "Window down" },
				["<A-k>"] = { "<C-w>k", "Window up" },

				-- save
				["<C-s>"] = { "<cmd>FormatWrite<CR>", "Save file (if modified)" },

				-- Allow moving the cursor through wrapped lines with j, k, <Up> and <Down>
				-- http://www.reddit.com/r/vim/comments/2k4cbr/problem_with_gj_and_gk/
				-- empty mode is same as using <cmd> :map
				-- also don't use g[j|k] when in operator pending mode, so it doesn't alter d, y or c behaviour

				-- ["<Down>"] = {
				-- 	function()
				-- 		vim.api.nvim_exec(vim.v.count == 0 and "normal! gj" or "normal! j", false)
				-- 	end,
				-- 	"Move up",
				-- 	opts = { expr = true },
				-- },
				["j"] = {
					function()
						vim.api.nvim_exec(vim.v.count == 0 and "normal! gj" or "normal! j", false)
					end,
					"Move up",
					opts = { expr = true },
				},
				-- ["<Up>"] = {
				-- 	function()
				-- 		vim.api.nvim_exec(vim.v.count == 0 and "normal! gk" or "normal! k", false)
				-- 	end,
				-- 	"Move up",
				-- 	opts = { expr = true },
				-- },
				["k"] = {
					function()
						vim.api.nvim_exec(vim.v.count == 0 and "normal! gk" or "normal! k", false)
					end,
					"Move up",
					opts = { expr = true },
				},

				-- new buffer
				["<leader>b"] = { "<cmd> enew <CR>", "New buffer" },
				["<leader>ch"] = { "<cmd> NvCheatsheet <CR>", "Mapping cheatsheet" },
			})
		end,
	},
  {
    'ojroques/nvim-osc52',
    lazy = false,
    init = function ()
      vim.keymap.set('n', 'y', require('osc52').copy_operator, { expr = true })
      vim.keymap.set('n', 'yy', 'yy', { remap = true })
      vim.keymap.set('v', 'y', require('osc52').copy_visual)

      vim.keymap.set('n', '<leader>C', require('osc52').copy_operator, {expr = true})
      vim.keymap.set('n', '<leader>CC', '<leader>C_', {remap = true})
      vim.keymap.set('v', '<leader>C', require('osc52').copy_visual)

      function copy()
        if vim.v.event.operator == 'y' and vim.v.event.regname == '+' then
          require('osc52').copy_register('+')
        end
      end

      vim.api.nvim_create_autocmd('TextYankPost', {callback = copy})
    end
  },
	{ "folke/neoconf.nvim", cmd = "Neoconf" },
	{ "folke/neodev.nvim" },
	{
		"vimwiki/vimwiki",
		lazy = false,
		init = function()
			g.vimwiki_global_ext = 0
			g.vimwiki_markdown_link_ext = 1
			g.vimwiki_links_space_char = "-"
			g.vimwiki_autowriteall = 1
			g.vimwiki_syntax = "markdown"
			g.vimwiki_ext = ".md"
			g.vimwiki_main = "README"
			g.vimwiki_auto_chdir = 1
			g.vimwiki_folding = ""

			vim.cmd([[

				let notes = {}
				let notes.path = "$HOME/documents/notes"

				let g:vimwiki_list = [notes]
				let g:vimwiki_ext2syntax = {
				  \ '.md': 'markdown',
				  \ '.markdown': 'markdown',
				  \ '.mdown': 'markdown'
				  \ }
        ]])
		end,
	},
	{
		"tools-life/taskwiki",
		lazy = false,
		enabled = true,
		dependencies = {
			"vimwiki/vimwiki",
		},
		init = function()
			g.taskwiki_taskrc_location = "~/.config/task/taskrc"
			g.taskwiki_data_location = "~/.local/share/task"
			g.taskwiki_dont_fold = "yes"
      g.taskwiki_sort_orders = { U = "urgency-" }
      -- TODO: These seem to lockup neovim
      -- vim.api.nvim_exec([[
      --   augroup TaskWiki
      --     autocmd!
      --     autocmd BufWritePost ~/documents/notes/REVIEW.md silent ! generate-tasks-review-markdown
      --     autocmd BufWritePost ~/documents/notes/NEXT.md silent ! generate-tasks-next-markdown
      --   augroup END
      -- ]], false)
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"c",
					"lua",
					"rust",
					"astro",
					"bash",
					"css",
					"diff",
					"dockerfile",
					"git_config",
					"git_rebase",
					"gitattributes",
					"gitcommit",
					"gitignore",
					"haskell",
					"html",
					"http",
					"ini",
					"javascript",
					"jq",
					"jsdoc",
					"json",
					"json5",
					"jsonc",
					"markdown",
					"markdown_inline",
					"ocaml",
					"python",
					"regex",
					"scss",
					"sql",
					"sxhkdrc",
					"toml",
					"tsx",
					"typescript",
					"vim",
					"vue",
					"yaml",
					-- "svelte",
				},
				highlight = { enable = true },
			})
		end,
	},
	{
		"williamboman/mason.nvim",
		init = function()
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					-- Broken "awk_ls",
					"astro",
					"bashls",
					"clangd",
					"cssmodules_ls",
					"cucumber_language_server",
					"denols",
					"dockerls",
					"docker_compose_language_service",
					"eslint",
					"elixirls",
					"elmls",
					"graphql",
					"html",
					-- Broken "hls",
					"jsonls",
					"tsserver",
					"zk",
					"marksman",
					"remark_ls",
					"vale_ls",
					-- "nil_ls",
					-- Broken "ocamllsp",
					"purescriptls",
					"jedi_language_server",
					"pyre",
					"pyright",
					-- "pylyzer",
					"sourcery",
					"pylsp",
					"ruff_lsp",
					"rescriptls",
					"reason_ls",
					"ruby_ls",
					--"solargraph",
					"sorbet",
					--"standardrb",
					"sqlls",
					"svelte",
					"taplo",
					"stylelint_lsp",
					"tailwindcss",
					"tsserver",
					"vimls",
					"vuels",
					"yamlls",
					"lemminx",
				},
			})
		end,
		build = ":MasonUpdate", -- :MasonUpdate updates registry contents
	},
	"williamboman/mason-lspconfig.nvim",
	"neovim/nvim-lspconfig",
	{
		"mfussenegger/nvim-lint",
		init = function()
			require("lint").linters_by_ft = {
				markdown = { "vale" },
				lua = { "luacheck" },
        -- typescript = { "eslint_d" },
				-- javascript = { "eslint_d" },
				-- typescriptreact = { "eslint_d" },
				json = { "jsonlint" },
				nix = { "nix" },
				yaml = { "yamllint" },
				vim = { "vint" },
			}
			-- vim.api.nvim_create_autocmd({ "BufWritePost", "VimEnter" }, {
			vim.api.nvim_create_autocmd({ "VimEnter", "TextChanged" }, {
				callback = function()
					require("lint").try_lint()
				end,
			})
		end,
	},
	{
		"mhartington/formatter.nvim",
		init = function()
			-- Utilities for creating configurations
			local util = require("formatter.util")

			-- Provides the Format, FormatWrite, FormatLock, and FormatWriteLock commands
			require("formatter").setup({
				-- Enable or disable logging
				logging = true,
				-- Set the log level
				log_level = vim.log.levels.WARN,
				-- All formatter configurations are opt-in
				filetype = {
					-- Formatter configurations for filetype "lua" go here
					-- and will be executed in order
					lua = {
						-- "formatter.filetypes.lua" defines default configurations for the
						-- "lua" filetype
						require("formatter.filetypes.lua").stylua,

						-- You can also define your own configuration
						function()
							-- Supports conditional formatting
							if util.get_current_buffer_file_name() == "special.lua" then
								return nil
							end

							-- Full specification of configurations is down below and in Vim help
							-- files
							return {
								exe = "stylua",
								args = {
									"--search-parent-directories",
									"--stdin-filepath",
									util.escape_path(util.get_current_buffer_file_path()),
									"--",
									"-",
								},
								stdin = true,
							}
						end,
					},

					-- Use the special "*" filetype for defining formatter configurations on
					-- any filetype
					["*"] = {
						-- "formatter.filetypes.any" defines default configurations for any
						-- filetype
						require("formatter.filetypes.any").remove_trailing_whitespace,
					},
				},
			})
		end,
	},
	{
		"navarasu/onedark.nvim",
		init = function()
			require("onedark").setup({
				-- Main options --
				-- Default theme style. Choose between 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer' and 'light'
				style = "cool",
				transparent = true, -- Show/hide background
				term_colors = true, -- Change terminal color as per the selected theme style
				ending_tildes = false, -- Show the end-of-buffer tildes. By default they are hidden
				cmp_itemkind_reverse = false, -- reverse item kind highlights in cmp menu

				-- Lualine options --
				lualine = {
					transparent = true, -- lualine center bar transparency
				},

				-- Custom Highlights --
				colors = {}, -- Override default colors
				highlights = {}, -- Override highlight groups

				-- Plugins Config --
				diagnostics = {
					darker = true, -- darker colors for diagnostic
					undercurl = true, -- use undercurl instead of underline for diagnostics
					background = true, -- use background color for virtual text
				},
			})
		end,
	},
	{
		"nvim-telescope/telescope.nvim",
		config = function()
			local wk = require("which-key")
			wk.register({
				["<leader>f"] = { name = "+file" },
				["<leader>fe"] = {
					function()
						OpenLfInFloaterm()
					end,
					"File Explorer",
				},
				["<leader>fn"] = { "<cmd>enew<cr>", "New File" },
				["<leader>ff"] = { "<cmd> Telescope find_files <CR>", "Find files" },
				["<leader>fa"] = {
					"<cmd> Telescope find_files follow=true no_ignore=true hidden=true <CR>",
					"Find all",
				},
				["<leader>fw"] = { "<cmd> Telescope live_grep <CR>", "Live grep" },

				["<leader>fB"] = { "<cmd> Telescope buffers <CR>", "Find buffers" },
				["<leader>fb"] = {
					"<cmd> Telescope live_grep grep_open_files=true prompt_title=Find\\ in\\ Buffers <CR>",
					"Find in buffers",
				},
				["<leader>fh"] = { "<cmd> Telescope help_tags <CR>", "Help page" },
				["<leader>fo"] = { "<cmd> Telescope oldfiles <CR>", "Find oldfiles" },
				["<leader>fz"] = { "<cmd> Telescope current_buffer_fuzzy_find <CR>", "Find in current buffer" },

				-- git
				["<leader>cm"] = { "<cmd> Telescope git_commits <CR>", "Git commits" },
				["<leader>gt"] = { "<cmd> Telescope git_status <CR>", "Git status" },

				["<leader>wK"] = {
					function()
						vim.cmd("WhichKey")
					end,
					"Which-key all keymaps",
				},
				["<leader>wk"] = {
					function()
						local input = vim.fn.input("WhichKey: ")
						vim.cmd("WhichKey " .. input)
					end,
					"Which-key query lookup",
				},
				["<leader>jl"] = {
					":FloatermNew --name=journallog --title=journal:log --height=1 journal log<cr>",
					"Journal: Log",
				},
				["<leader>jt"] = {
					":FloatermNew --name=journaltask --title=journal:task --height=1 journal task<cr>",
					"Journal: Task",
				},
			})
		end,
		branch = "0.1.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"BurntSushi/ripgrep",
			"sharkdp/fd",
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
	},

	{
		"jackMort/ChatGPT.nvim",
		lazy = false,
		dependencies = {
			"MunifTanjim/nui.nvim",
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			require("chatgpt").setup({
				yank_register = "+",
				edit_with_instructions = {
					diff = false,
					keymaps = {
						accept = "<C-y>",
						toggle_diff = "<C-d>",
						toggle_settings = "<C-o>",
						cycle_windows = "<Tab>",
						use_output_as_input = "<C-i>",
					},
				},
				chat = {
					-- welcome_message = WELCOME_MESSAGE,
					loading_text = "Loading, please wait ...",
					question_sign = "", -- 🙂
					answer_sign = "ﮧ", -- 🤖
					max_line_length = 120,
					sessions_window = {
						border = {
							style = "rounded",
							text = {
								top = " Sessions ",
							},
						},
						win_options = {
							winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
						},
					},
					keymaps = {
						close = { "<C-c>" },
						yank_last = "<C-y>",
						yank_last_code = "<C-k>",
						scroll_up = "<C-u>",
						scroll_down = "<C-d>",
						toggle_settings = "<C-o>",
						new_session = "<C-n>",
						cycle_windows = "<Tab>",
						select_session = "<Space>",
						rename_session = "r",
						delete_session = "d",
					},
				},
				popup_layout = {
					relative = "editor",
					position = "50%",
					size = {
						height = "80%",
						width = "80%",
					},
				},
				popup_window = {
					filetype = "chatgpt",
					border = {
						highlight = "FloatBorder",
						style = "rounded",
						text = {
							top = " ChatGPT ",
						},
					},
					win_options = {
						winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
					},
				},
				popup_input = {
					prompt = "  ",
					border = {
						highlight = "FloatBorder",
						style = "rounded",
						text = {
							top_align = "center",
							top = " Prompt ",
						},
					},
					win_options = {
						winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
					},
					submit = "<C-Enter>",
				},
				settings_window = {
					border = {
						style = "rounded",
						text = {
							top = " Settings ",
						},
					},
					win_options = {
						winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
					},
				},
				openai_params = {
					model = "gpt-4",
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
				actions_paths = {},
				predefined_chat_gpt_prompts = "https://raw.githubusercontent.com/f/awesome-chatgpt-prompts/main/prompts.csv",
			})
		end,
		requires = {
			"MunifTanjim/nui.nvim",
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
		},
	},

	-- {
	-- 	"zbirenbaum/copilot-cmp",
	-- 	after = { "copilot.lua" },
	-- 	lazy = false,
	-- 	config = function()
	-- 		require("copilot_cmp").setup({})
	-- 	end,
	-- },

	{
		"rmagatti/auto-session",
		lazy = false,
		config = function()
			require("auto-session").setup({
				log_level = "error",
				auto_session_suppress_dirs = { "~/", "~/downloads", "/" },
			})
		end,
	},

	{ lazy = false, "tpope/vim-eunuch" },
	{ lazy = false, "nelstrom/vim-visual-star-search" },
	{ lazy = false, "machakann/vim-highlightedyank" },

	--expand region (+/-)
	{ lazy = false, "terryma/vim-expand-region" },

	{
		"nvim-lualine/lualine.nvim",
		requires = { "nvim-tree/nvim-web-devicons", opt = true },
		lazy = false,
		config = function()
			vim.g.my_global_var = true

			local tabs = {
				"tabs",
				max_length = vim.o.columns / 3, -- Maximum width of tabs component.
				-- Note:
				-- It can also be a function that returns
				-- the value of `max_length` dynamically.
				mode = 2, -- 0: Shows tab_nr
				-- 1: Shows tab_name
				-- 2: Shows tab_nr + tab_name

				-- Automatically updates active tab color to match color of other components (will be overidden if buffers_color is set)
				use_mode_colors = false,
				tabs_color = {
					-- Same values as the general color option can be used here.
					-- active = 'lualine_{section}_normal',     -- Color for active tab.
					-- inactive = 'lualine_{section}_inactive', -- Color for inactive tab.
				},

				fmt = function(name, context)
					-- Show + if buffer is modified in tab
					local buflist = vim.fn.tabpagebuflist(context.tabnr)
					local winnr = vim.fn.tabpagewinnr(context.tabnr)
					local bufnr = buflist[winnr]
					local mod = vim.fn.getbufvar(bufnr, "&mod")

					return name .. (mod == 1 and " +" or "")
				end,
			}

			require("lualine").setup({
				options = {
					icons_enabled = true,
					theme = "onedark",
					component_separators = { left = "", right = "" },
					section_separators = { left = "", right = "" },
					disabled_filetypes = {
						statusline = {},
						winbar = {},
					},
					ignore_focus = {},
					always_divide_middle = false,
					globalstatus = true,
					refresh = {
						statusline = 1000,
						tabline = 1000,
						winbar = 1000,
					},
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = { "branch", "diff", "diagnostics" },
					lualine_c = { "filename" },

					lualine_x = { tabs, "encoding", "fileformat", "filetype" },
					lualine_y = { "progress" },
					lualine_z = { "location" },
				},
				inactive_sections = {
					lualine_a = {},
					lualine_b = {},
					lualine_c = { "filename" },
					lualine_x = { "location" },
					lualine_y = {},
					lualine_z = {},
				},
				tabline = {},
				winbar = {},
				inactive_winbar = {},
				extensions = {},
			})
		end,
	},

	{
		"voldikss/vim-floaterm",
		lazy = false,
	},

	-- incremental search improved
	{ "haya14busa/is.vim", lazy = false },

	{
		"bennypowers/nvim-regexplainer",
		lazy = false,
		config = function()
			require("regexplainer").setup({
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
			})
		end,
		requires = {
			"nvim-treesitter/nvim-treesitter",
			"MunifTanjim/nui.nvim",
		},
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
		"NvChad/nvterm",
		config = function()
			require("nvterm").setup({
				terminals = {
					shell = vim.o.shell,
					list = {},
					type_opts = {
						float = {
							relative = "editor",
							row = 0.3,
							col = 0.25,
							width = 0.5,
							height = 0.4,
							border = "single",
						},
						horizontal = { location = "rightbelow", split_ratio = 0.3 },
						vertical = { location = "rightbelow", split_ratio = 0.5 },
					},
				},
				behavior = {
					autoclose_on_quit = {
						enabled = false,
						confirm = true,
					},
					close_on_exit = true,
					auto_insert = true,
				},
			})

			local wk = require("which-key")

			wk.register({
				["<A-.>"] = {
					function()
						require("nvterm.terminal").toggle("vertical")
					end,
					"Vertical Split Terminal",
				},
				["<A-C-.>"] = {
					function()
						require("nvterm.terminal").toggle("horizontal")
					end,
					"Vertical Split Terminal",
				},
			})
		end,
	},

	{
		"rmagatti/goto-preview",
		lazy = false,
		config = function()
			local wk = require("which-key")
			local gp = require("goto-preview")

			gp.setup({
				width = 120, -- Width of the floating window
				height = 15, -- Height of the floating window
				border = { "↖", "─", "┐", "│", "┘", "─", "└", "│" }, -- Border characters of the floating window
				default_mappings = false, -- Bind default mappings
				debug = false, -- Print debug information
				opacity = nil, -- 0-100 opacity level of the floating window where 100 is fully transparent.
				resizing_mappings = false, -- Binds arrow keys to resizing the floating window.
				post_open_hook = nil, -- A function taking two arguments, a buffer and a window to be ran as a hook.
				references = { -- Configure the telescope UI for slowing the references cycling window.
					telescope = require("telescope.themes").get_dropdown({ hide_preview = false }),
				},
				-- These two configs can also be passed down to the goto-preview definition and implementation calls for one off "peak" functionality.
				focus_on_open = true, -- Focus the floating window when opening it.
				dismiss_on_move = false, -- Dismiss the floating window when moving the cursor.
				force_close = true, -- passed into vim.api.nvim_win_close's second argument. See :h nvim_win_close
				bufhidden = "wipe", -- the bufhidden option to set on the floating window. See :h bufhidden
			})

			wk.register({
				gpd = {
					function()
						gp.goto_preview_definition()
					end,
					"popup preview definition",
					noremap = true,
				},
				gpt = {
					function()
						gp.goto_preview_type_definition()
					end,
					"popup preview type definition",
					noremap = true,
				},
				gP = {
					function()
						gp.close_all_win()
					end,
					"close all popup previews",
					noremap = true,
				},
				gpr = {
					function()
						gp.goto_preview_references()
					end,
					"popup all code references",
					noremap = true,
				},
			}, { mode = "n" })
		end,
		requires = { "folke/which-key.nvim" },
	},

	{
		"haringsrob/nvim_context_vt",
		lazy = false,
		requires = "nvim-treesitter/nvim-treesitter",
		init = function()
			require("nvim_context_vt").setup({
				-- Enable by default. You can disable and use :NvimContextVtToggle to maually enable.
				-- Default: true
				enabled = true,

				-- Override default virtual text prefix
				-- Default: '-->'
				prefix = "",

				-- Override the internal highlight group name
				-- Default: 'ContextVt'
				-- highlight = 'CustomContextVt',

				-- Disable virtual text for given filetypes
				-- Default: { 'markdown' }
				disable_ft = { "markdown" },

				-- Disable display of virtual text below blocks for indentation based languages like Python
				-- Default: false
				disable_virtual_lines = false,

				-- Same as above but only for spesific filetypes
				-- Default: {}
				-- disable_virtual_lines_ft = { 'yaml' },

				-- How many lines required after starting position to show virtual text
				-- Default: 1 (equals two lines total)
				min_rows = 1,

				-- Same as above but only for spesific filetypes
				-- Default: {}
				min_rows_ft = {},

				-- Custom virtual text node parser callback
				-- Default: nil
				-- custom_parser = function(node, ft, opts)
				--   local utils = require('nvim_context_vt.utils')
				--
				--   -- If you return `nil`, no virtual text will be displayed.
				--   if node:type() == 'function' then
				--     return nil
				--   end
				--
				--   -- This is the standard text
				--   return '--> ' .. utils.get_node_text(node)[1]
				-- end,

				-- Custom node validator callback
				-- Default: nil
				-- custom_validator = function(node, ft, opts)
				--   -- Internally a node is matched against min_rows and configured targets
				--   local default_validator = require('nvim_context_vt.utils').default_validator
				--   if default_validator(node, ft) then
				--     -- Custom behaviour after using the internal validator
				--     if node:type() == 'function' then
				--       return false
				--     end
				--   end
				--
				--   return true
				-- end,

				-- Custom node virtual text resolver callback
				-- Default: nil
				-- custom_resolver = function(nodes, ft, opts)
				--   -- By default the last node is used
				--   return nodes[#nodes]
				-- end,
			})
		end,
	},

	-- { "lukas-reineke/indent-blankline.nvim" },
	{
		"lewis6991/gitsigns.nvim",
		init = function()
			require("gitsigns").setup()
		end,
	},

  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
      { 'tpope/vim-dadbod', lazy = true },
      { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
    },
    cmd = {
      'DBUI',
      'DBUIToggle',
      'DBUIAddConnection',
      'DBUIFindBuffer',
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },

	{
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
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
			require("octo").setup({
				default_remote = { "upstream", "origin" }, -- order to try remotes
				ssh_aliases = {}, -- SSH aliases. e.g. `ssh_aliases = {["github.com-work"] = "github.com"}`
				reaction_viewer_hint_icon = "", -- marker for user reactions
				user_icon = " ", -- user icon
				timeline_marker = "", -- timeline marker
				timeline_indent = "2", -- timeline indentation
				right_bubble_delimiter = "", -- bubble delimiter
				left_bubble_delimiter = "", -- bubble delimiter
				github_hostname = "", -- GitHub Enterprise host
				snippet_context_lines = 4, -- number or lines around commented lines
				gh_env = {}, -- extra environment variables to pass on to GitHub CLI, can be a table or function returning a table
				issues = {
					order_by = { -- criteria to sort results of `Octo issue list`
						field = "CREATED_AT", -- either COMMENTS, CREATED_AT or UPDATED_AT (https://docs.github.com/en/graphql/reference/enums#issueorderfield)
						direction = "DESC", -- either DESC or ASC (https://docs.github.com/en/graphql/reference/enums#orderdirection)
					},
				},
				pull_requests = {
					order_by = { -- criteria to sort the results of `Octo pr list`
						field = "CREATED_AT", -- either COMMENTS, CREATED_AT or UPDATED_AT (https://docs.github.com/en/graphql/reference/enums#issueorderfield)
						direction = "DESC", -- either DESC or ASC (https://docs.github.com/en/graphql/reference/enums#orderdirection)
					},
					always_select_remote_on_create = "false", -- always give prompt to select base remote repo when creating PRs
				},
				file_panel = {
					size = 10, -- changed files panel rows
					use_icons = true, -- use web-devicons in file panel (if false, nvim-web-devicons does not need to be installed)
				},
				mappings = {
					issue = {
						close_issue = { lhs = "<space>ic", desc = "close issue" },
						reopen_issue = { lhs = "<space>io", desc = "reopen issue" },
						list_issues = { lhs = "<space>il", desc = "list open issues on same repo" },
						reload = { lhs = "<C-r>", desc = "reload issue" },
						open_in_browser = { lhs = "<C-b>", desc = "open issue in browser" },
						copy_url = { lhs = "<C-y>", desc = "copy url to system clipboard" },
						add_assignee = { lhs = "<space>aa", desc = "add assignee" },
						remove_assignee = { lhs = "<space>ad", desc = "remove assignee" },
						create_label = { lhs = "<space>lc", desc = "create label" },
						add_label = { lhs = "<space>la", desc = "add label" },
						remove_label = { lhs = "<space>ld", desc = "remove label" },
						goto_issue = { lhs = "<space>gi", desc = "navigate to a local repo issue" },
						add_comment = { lhs = "<space>ca", desc = "add comment" },
						delete_comment = { lhs = "<space>cd", desc = "delete comment" },
						next_comment = { lhs = "]c", desc = "go to next comment" },
						prev_comment = { lhs = "[c", desc = "go to previous comment" },
						react_hooray = { lhs = "<space>rp", desc = "add/remove 🎉 reaction" },
						react_heart = { lhs = "<space>rh", desc = "add/remove ❤️ reaction" },
						react_eyes = { lhs = "<space>re", desc = "add/remove 👀 reaction" },
						react_thumbs_up = { lhs = "<space>r+", desc = "add/remove 👍 reaction" },
						react_thumbs_down = { lhs = "<space>r-", desc = "add/remove 👎 reaction" },
						react_rocket = { lhs = "<space>rr", desc = "add/remove 🚀 reaction" },
						react_laugh = { lhs = "<space>rl", desc = "add/remove 😄 reaction" },
						react_confused = { lhs = "<space>rc", desc = "add/remove 😕 reaction" },
					},
					pull_request = {
						checkout_pr = { lhs = "<space>po", desc = "checkout PR" },
						merge_pr = { lhs = "<space>pm", desc = "merge commit PR" },
						squash_and_merge_pr = { lhs = "<space>psm", desc = "squash and merge PR" },
						list_commits = { lhs = "<space>pc", desc = "list PR commits" },
						list_changed_files = { lhs = "<space>pf", desc = "list PR changed files" },
						show_pr_diff = { lhs = "<space>pd", desc = "show PR diff" },
						add_reviewer = { lhs = "<space>va", desc = "add reviewer" },
						remove_reviewer = { lhs = "<space>vd", desc = "remove reviewer request" },
						close_issue = { lhs = "<space>ic", desc = "close PR" },
						reopen_issue = { lhs = "<space>io", desc = "reopen PR" },
						list_issues = { lhs = "<space>il", desc = "list open issues on same repo" },
						reload = { lhs = "<C-r>", desc = "reload PR" },
						open_in_browser = { lhs = "<C-b>", desc = "open PR in browser" },
						copy_url = { lhs = "<C-y>", desc = "copy url to system clipboard" },
						goto_file = { lhs = "gf", desc = "go to file" },
						add_assignee = { lhs = "<space>aa", desc = "add assignee" },
						remove_assignee = { lhs = "<space>ad", desc = "remove assignee" },
						create_label = { lhs = "<space>lc", desc = "create label" },
						add_label = { lhs = "<space>la", desc = "add label" },
						remove_label = { lhs = "<space>ld", desc = "remove label" },
						goto_issue = { lhs = "<space>gi", desc = "navigate to a local repo issue" },
						add_comment = { lhs = "<space>ca", desc = "add comment" },
						delete_comment = { lhs = "<space>cd", desc = "delete comment" },
						next_comment = { lhs = "]c", desc = "go to next comment" },
						prev_comment = { lhs = "[c", desc = "go to previous comment" },
						react_hooray = { lhs = "<space>rp", desc = "add/remove 🎉 reaction" },
						react_heart = { lhs = "<space>rh", desc = "add/remove ❤️ reaction" },
						react_eyes = { lhs = "<space>re", desc = "add/remove 👀 reaction" },
						react_thumbs_up = { lhs = "<space>r+", desc = "add/remove 👍 reaction" },
						react_thumbs_down = { lhs = "<space>r-", desc = "add/remove 👎 reaction" },
						react_rocket = { lhs = "<space>rr", desc = "add/remove 🚀 reaction" },
						react_laugh = { lhs = "<space>rl", desc = "add/remove 😄 reaction" },
						react_confused = { lhs = "<space>rc", desc = "add/remove 😕 reaction" },
					},
					review_thread = {
						goto_issue = { lhs = "<space>gi", desc = "navigate to a local repo issue" },
						add_comment = { lhs = "<space>ca", desc = "add comment" },
						add_suggestion = { lhs = "<space>sa", desc = "add suggestion" },
						delete_comment = { lhs = "<space>cd", desc = "delete comment" },
						next_comment = { lhs = "]c", desc = "go to next comment" },
						prev_comment = { lhs = "[c", desc = "go to previous comment" },
						select_next_entry = { lhs = "]q", desc = "move to previous changed file" },
						select_prev_entry = { lhs = "[q", desc = "move to next changed file" },
						close_review_tab = { lhs = "<C-c>", desc = "close review tab" },
						react_hooray = { lhs = "<space>rp", desc = "add/remove 🎉 reaction" },
						react_heart = { lhs = "<space>rh", desc = "add/remove ❤️ reaction" },
						react_eyes = { lhs = "<space>re", desc = "add/remove 👀 reaction" },
						react_thumbs_up = { lhs = "<space>r+", desc = "add/remove 👍 reaction" },
						react_thumbs_down = { lhs = "<space>r-", desc = "add/remove 👎 reaction" },
						react_rocket = { lhs = "<space>rr", desc = "add/remove 🚀 reaction" },
						react_laugh = { lhs = "<space>rl", desc = "add/remove 😄 reaction" },
						react_confused = { lhs = "<space>rc", desc = "add/remove 😕 reaction" },
					},
					submit_win = {
						approve_review = { lhs = "<C-a>", desc = "approve review" },
						comment_review = { lhs = "<C-m>", desc = "comment review" },
						request_changes = { lhs = "<C-r>", desc = "request changes review" },
						close_review_tab = { lhs = "<C-c>", desc = "close review tab" },
					},
					review_diff = {
						add_review_comment = { lhs = "<space>ca", desc = "add a new review comment" },
						add_review_suggestion = { lhs = "<space>sa", desc = "add a new review suggestion" },
						focus_files = { lhs = "<leader>e", desc = "move focus to changed file panel" },
						toggle_files = { lhs = "<leader>b", desc = "hide/show changed files panel" },
						next_thread = { lhs = "]t", desc = "move to next thread" },
						prev_thread = { lhs = "[t", desc = "move to previous thread" },
						select_next_entry = { lhs = "]q", desc = "move to previous changed file" },
						select_prev_entry = { lhs = "[q", desc = "move to next changed file" },
						close_review_tab = { lhs = "<C-c>", desc = "close review tab" },
						toggle_viewed = { lhs = "<leader><space>", desc = "toggle viewer viewed state" },
					},
					file_panel = {
						next_entry = { lhs = "j", desc = "move to next changed file" },
						prev_entry = { lhs = "k", desc = "move to previous changed file" },
						select_entry = { lhs = "<cr>", desc = "show selected changed file diffs" },
						refresh_files = { lhs = "R", desc = "refresh changed files panel" },
						focus_files = { lhs = "<leader>e", desc = "move focus to changed file panel" },
						toggle_files = { lhs = "<leader>b", desc = "hide/show changed files panel" },
						select_next_entry = { lhs = "]q", desc = "move to previous changed file" },
						select_prev_entry = { lhs = "[q", desc = "move to next changed file" },
						close_review_tab = { lhs = "<C-c>", desc = "close review tab" },
						toggle_viewed = { lhs = "<leader><space>", desc = "toggle viewer viewed state" },
					},
				},
			})
		end,
	},
	{
		ft = "markdown.mdx",
		"jxnblk/vim-mdx-js",
	},
	{
		"folke/todo-comments.nvim",
		requires = "nvim-lua/plenary.nvim",
		lazy = false,
		config = function()
			require("todo-comments").setup({
				signs = true, -- show icons in the signs column
				sign_priority = 8, -- sign priority
				-- keywords recognized as todo comments
				keywords = {
					FIX = {
						icon = " ", -- icon used for the sign, and in search results
						color = "error", -- can be a hex color, or a named color (see below)
						alt = { "FIXME", "BUG", "FIXIT", "ISSUE", "FIX" }, -- a set of other keywords that all map to this FIX keywords
						-- signs = false, -- configure signs for some keywords individually
					},
					TODO = { icon = " ", color = "info" },
					HACK = { icon = " ", color = "warning" },
					WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
					PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
					NOTE = { icon = " ", color = "hint", alt = { "INFO", "ASK" } },
					TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
				},
				gui_style = {
					fg = "BOLD", -- The gui style to use for the fg highlight group.
					bg = "BOLD", -- The gui style to use for the bg highlight group.
				},
				merge_keywords = true, -- when true, custom keywords will be merged with the defaults
				-- highlighting of the line containing the todo comment
				-- * before: highlights before the keyword (typically comment characters)
				-- * keyword: highlights of the keyword
				-- * after: highlights after the keyword (todo text)
				highlight = {
					multiline = true, -- enable multine todo comments
					multiline_pattern = "^.", -- lua pattern to match the next multiline from the start of the matched keyword
					multiline_context = 10, -- extra lines that will be re-evaluated when changing a line
					before = "", -- "fg" or "bg" or empty
					keyword = "wide", -- "fg", "bg", "wide", "wide_bg", "wide_fg" or empty. (wide and wide_bg is the same as bg, but will also highlight surrounding characters, wide_fg acts accordingly but with fg)
					after = "", -- "fg" or "bg" or empty
					pattern = [[.*<(KEYWORDS)\s*:]], -- pattern or table of patterns, used for highlightng (vim regex)
					comments_only = true, -- uses treesitter to match keywords in comments only
					max_line_len = 400, -- ignore lines longer than this
					exclude = {}, -- list of file types to exclude highlighting
				},
				-- list of named colors where we try to extract the guifg from the
				-- list of highlight groups or use the hex color if hl not found as a fallback
				colors = {
					error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
					warning = { "DiagnosticWarn", "WarningMsg", "#FBBF24" },
					-- info = { "DiagnosticInfo", "#2563EB" },
					info = { "DiagnosticInfo", "#00FF00" },
					hint = { "DiagnosticHint", "#10B981" },
					default = { "Identifier", "#7C3AED" },
					test = { "Identifier", "#FF00FF" },
				},
				search = {
					command = "rg",
					args = {
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
					},
					-- regex that will be used to match keywords.
					-- don't replace the (KEYWORDS) placeholder
					pattern = [[\b(KEYWORDS):]], -- ripgrep regex
					-- pattern = [[\b(KEYWORDS)\b]], -- match without the extra colon. You'll likely get false positives
				},
			})
		end,
	},
	{
		"ThePrimeagen/git-worktree.nvim",
		lazy = false,
		config = function()
			local wk = require("which-key")

			wk.register({
				["<F11>"] = {
					"<cmd>lua require('telescope').extensions.git_worktree.git_worktrees()<cr>",
					"List worktrees",
				},
				["<F12>"] = {
					"<cmd>lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>",
					"Create worktree",
				},
			})
		end,
		requires = {
			"folke/which-key.nvim",
			"plenary.nvim",
			"nvim-telescope/telescope.nvim",
		},
	},
	{
		"phaazon/hop.nvim",
		lazy = false,
		init = function()
			local hop = require("hop")
			local wk = require("which-key")

			hop.setup({
				keys = "fjdksla:ghrueiwoqpvmcnxbzty,.",
				multi_windows = true,
			})

			wk.register({
				j = {
					function()
						hop.hint_vertical({
							direction = require("hop.hint").HintDirection.AFTER_CURSOR,
						})
					end,
					"Hop down below cursor",
				},
				k = {
					function()
						hop.hint_vertical({
							direction = require("hop.hint").HintDirection.BEFORE_CURSOR,
						})
					end,
					"Hop up above cursor",
				},
				s = {
					function()
						hop.hint_char2()
					end,
					"Hop to word with 2 characters",
				},
			}, { mode = "v" })

			wk.register({
				s = {
					function()
						hop.hint_char2()
					end,
					"Hop to word with 2 characters",
				},
			}, { mode = "n" })

			wk.register({
				s = {
					function()
						hop.hint_char2()
					end,
					"Hop to word with 2 characters",
				},
				j = {
					function()
						hop.hint_vertical({
							direction = require("hop.hint").HintDirection.AFTER_CURSOR,
						})
					end,
					"Hop down below cursor",
				},
				k = {
					function()
						hop.hint_vertical({
							direction = require("hop.hint").HintDirection.BEFORE_CURSOR,
						})
					end,
					"Hop up above cursor",
				},
			}, { mode = "x" })
		end,
	},

	{
		"folke/zen-mode.nvim",
		lazy = false,
		config = function()
			local zen = require("zen-mode")
			local wk = require("which-key")

			zen.setup({
				{
					window = {
						backdrop = 0.95, -- shade the backdrop of the Zen window. Set to 1 to keep the same as Normal
						-- height and width can be:
						-- * an absolute number of cells when > 1
						-- * a percentage of the width / height of the editor when <= 1
						-- * a function that returns the width or the height
						width = 120, -- width of the Zen window
						height = 1, -- height of the Zen window
						-- by default, no options are changed for the Zen window
						-- uncomment any of the options below, or add other vim.wo options you want to apply
						options = {
							-- signcolumn = "no", -- disable signcolumn
							-- number = false, -- disable number column
							-- relativenumber = false, -- disable relative numbers
							-- cursorline = false, -- disable cursorline
							-- cursorcolumn = false, -- disable cursor column
							-- foldcolumn = "0", -- disable fold column
							-- list = false, -- disable whitespace characters
						},
					},
					plugins = {
						-- disable some global vim options (vim.o...)
						-- comment the lines to not apply the options
						options = {
							enabled = true,
							ruler = false, -- disables the ruler text in the cmd line area
							showcmd = false, -- disables the command in the last line of the screen
						},
						twilight = { enabled = false }, -- enable to start Twilight when zen mode opens
						gitsigns = { enabled = true }, -- disables git signs
						tmux = { enabled = true }, -- disables the tmux statusline
						-- this will change the font size on kitty when in zen mode
						-- to make this work, you need to set the following kitty options:
						-- - allow_remote_control socket-only
						-- - listen_on unix:/tmp/kitty
						kitty = {
							enabled = true,
							font = "+4", -- font size increment
						},
					},
					-- callback where you can add custom code when the Zen window opens
					on_open = function(win) end,
					-- callback where you can add custom code when the Zen window closes
					on_close = function() end,
				},
			})

			wk.register({
				["<A-m>"] = { "<cmd>ZenMode<cr>", "Toggle zen mode", noremap = true },
			})
		end,
	},

	--Swap windows without ruining your layout!
	{
		"wesQ3/vim-windowswap",
		lazy = false,
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
		end,
	},

	{
		"windwp/nvim-ts-autotag",
		lazy = false,
		config = function()
			require("nvim-ts-autotag").setup({
				filetypes = {
					"html",
					"javascript",
					"typescript",
					"javascriptreact",
					"typescriptreact",
					"svelte",
					"vue",
					"tsx",
					"jsx",
					"rescript",
					"xml",
					"php",
					"markdown",
					"glimmer",
					"handlebars",
					"hbs",
				},
				skip_tags = {
					"area",
					"base",
					"br",
					"col",
					"command",
					"embed",
					"hr",
					"img",
					"slot",
					"input",
					"keygen",
					"link",
					"meta",
					"param",
					"source",
					"track",
					"wbr",
					"menuitem",
				},
			})
		end,
	},
	{
		"sindrets/winshift.nvim",
		lazy = false,
		config = function()
			require("winshift").setup({
				keymaps = {
					disable_defaults = true, -- Disable the default keymaps
				},
			})
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
			local actions = require("diffview.actions")

			require("diffview").setup({
				diff_binaries = false, -- Show diffs for binaries
				enhanced_diff_hl = false, -- See ':h diffview-config-enhanced_diff_hl'
				git_cmd = { "git" }, -- The git executable followed by default args.
				use_icons = true, -- Requires nvim-web-devicons
				show_help_hints = true, -- Show hints for how to open the help panel
				watch_index = true, -- Update views and index buffers when the git index changes.
				icons = { -- Only applies when use_icons is true.
					folder_closed = "",
					folder_open = "",
				},
				signs = {
					fold_closed = "",
					fold_open = "",
					done = "✓",
				},
				view = {
					-- Configure the layout and behavior of different types of views.
					-- Available layouts:
					--  'diff1_plain'
					--    |'diff2_horizontal'
					--    |'diff2_vertical'
					--    |'diff3_horizontal'
					--    |'diff3_vertical'
					--    |'diff3_mixed'
					--    |'diff4_mixed'
					-- For more info, see ':h diffview-config-view.x.layout'.
					default = {
						-- Config for changed files, and staged files in diff views.
						layout = "diff2_horizontal",
					},
					merge_tool = {
						-- Config for conflicted files in diff views during a merge or rebase.
						layout = "diff3_mixed",
						disable_diagnostics = true, -- Temporarily disable diagnostics for conflict buffers while in the view.
					},
					file_history = {
						-- Config for changed files in file history views.
						layout = "diff2_horizontal",
					},
				},
				file_panel = {
					listing_style = "tree", -- One of 'list' or 'tree'
					tree_options = { -- Only applies when listing_style is 'tree'
						flatten_dirs = true, -- Flatten dirs that only contain one single dir
						folder_statuses = "only_folded", -- One of 'never', 'only_folded' or 'always'.
					},
					win_config = { -- See ':h diffview-config-win_config'
						position = "left",
						width = 35,
						win_opts = {},
					},
				},
				file_history_panel = {
					log_options = { -- See ':h diffview-config-log_options'
						git = {
							single_file = {
								diff_merges = "combined",
							},
							multi_file = {
								diff_merges = "first-parent",
							},
						},
						hg = {
							single_file = {},
							multi_file = {},
						},
					},
					win_config = { -- See ':h diffview-config-win_config'
						position = "bottom",
						height = 16,
						win_opts = {},
					},
				},
				commit_log_panel = {
					win_config = { -- See ':h diffview-config-win_config'
						win_opts = {},
					},
				},
				default_args = { -- Default args prepended to the arg-list for the listed commands
					DiffviewOpen = {},
					DiffviewFileHistory = {},
				},
				hooks = {}, -- See ':h diffview-config-hooks'
				keymaps = {
					disable_defaults = false, -- Disable the default keymaps
					view = {
						-- The `view` bindings are active in the diff buffers, only when the current
						-- tabpage is a Diffview.
						{ "n", "<tab>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
						{ "n", "<s-tab>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
						{
							"n",
							"gf",
							actions.goto_file,
							{ desc = "Open the file in a new split in the previous tabpage" },
						},
						{ "n", "<C-w><C-f>", actions.goto_file_split, { desc = "Open the file in a new split" } },
						{ "n", "<C-w>gf", actions.goto_file_tab, { desc = "Open the file in a new tabpage" } },
						{ "n", "<leader>e", actions.focus_files, { desc = "Bring focus to the file panel" } },
						{ "n", "<leader>b", actions.toggle_files, { desc = "Toggle the file panel." } },
						{ "n", "g<C-x>", actions.cycle_layout, { desc = "Cycle through available layouts." } },
						{
							"n",
							"[x",
							actions.prev_conflict,
							{ desc = "In the merge-tool: jump to the previous conflict" },
						},
						{ "n", "]x", actions.next_conflict, { desc = "In the merge-tool: jump to the next conflict" } },
						{
							"n",
							"<leader>co",
							actions.conflict_choose("ours"),
							{ desc = "Choose the OURS version of a conflict" },
						},
						{
							"n",
							"<leader>ct",
							actions.conflict_choose("theirs"),
							{ desc = "Choose the THEIRS version of a conflict" },
						},
						{
							"n",
							"<leader>cb",
							actions.conflict_choose("base"),
							{ desc = "Choose the BASE version of a conflict" },
						},
						{
							"n",
							"<leader>ca",
							actions.conflict_choose("all"),
							{ desc = "Choose all the versions of a conflict" },
						},
						{ "n", "dx", actions.conflict_choose("none"), { desc = "Delete the conflict region" } },
					},
					diff1 = {
						-- Mappings in single window diff layouts
						{ "n", "g?", actions.help({ "view", "diff1" }), { desc = "Open the help panel" } },
					},
					diff2 = {
						-- Mappings in 2-way diff layouts
						{ "n", "g?", actions.help({ "view", "diff2" }), { desc = "Open the help panel" } },
					},
					diff3 = {
						-- Mappings in 3-way diff layouts
						{
							{ "n", "x" },
							"2do",
							actions.diffget("ours"),
							{ desc = "Obtain the diff hunk from the OURS version of the file" },
						},
						{
							{ "n", "x" },
							"3do",
							actions.diffget("theirs"),
							{ desc = "Obtain the diff hunk from the THEIRS version of the file" },
						},
						{ "n", "g?", actions.help({ "view", "diff3" }), { desc = "Open the help panel" } },
					},
					diff4 = {
						-- Mappings in 4-way diff layouts
						{
							{ "n", "x" },
							"1do",
							actions.diffget("base"),
							{ desc = "Obtain the diff hunk from the BASE version of the file" },
						},
						{
							{ "n", "x" },
							"2do",
							actions.diffget("ours"),
							{ desc = "Obtain the diff hunk from the OURS version of the file" },
						},
						{
							{ "n", "x" },
							"3do",
							actions.diffget("theirs"),
							{ desc = "Obtain the diff hunk from the THEIRS version of the file" },
						},
						{ "n", "g?", actions.help({ "view", "diff4" }), { desc = "Open the help panel" } },
					},
					file_panel = {
						{ "n", "j", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
						{ "n", "<down>", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
						{ "n", "k", actions.prev_entry, { desc = "Bring the cursor to the previous file entry." } },
						{ "n", "<up>", actions.prev_entry, { desc = "Bring the cursor to the previous file entry." } },
						{ "n", "<cr>", actions.select_entry, { desc = "Open the diff for the selected entry." } },
						{ "n", "o", actions.select_entry, { desc = "Open the diff for the selected entry." } },
						{
							"n",
							"<2-LeftMouse>",
							actions.select_entry,
							{ desc = "Open the diff for the selected entry." },
						},
						{ "n", "-", actions.toggle_stage_entry, { desc = "Stage / unstage the selected entry." } },
						{ "n", "S", actions.stage_all, { desc = "Stage all entries." } },
						{ "n", "U", actions.unstage_all, { desc = "Unstage all entries." } },
						{ "n", "X", actions.restore_entry, { desc = "Restore entry to the state on the left side." } },
						{ "n", "L", actions.open_commit_log, { desc = "Open the commit log panel." } },
						{ "n", "<c-b>", actions.scroll_view(-0.25), { desc = "Scroll the view up" } },
						{ "n", "<c-f>", actions.scroll_view(0.25), { desc = "Scroll the view down" } },
						{ "n", "<tab>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
						{ "n", "<s-tab>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
						{
							"n",
							"gf",
							actions.goto_file,
							{ desc = "Open the file in a new split in the previous tabpage" },
						},
						{ "n", "<C-w><C-f>", actions.goto_file_split, { desc = "Open the file in a new split" } },
						{ "n", "<C-w>gf", actions.goto_file_tab, { desc = "Open the file in a new tabpage" } },
						{ "n", "i", actions.listing_style, { desc = "Toggle between 'list' and 'tree' views" } },
						{
							"n",
							"f",
							actions.toggle_flatten_dirs,
							{ desc = "Flatten empty subdirectories in tree listing style." },
						},
						{ "n", "R", actions.refresh_files, { desc = "Update stats and entries in the file list." } },
						{ "n", "<leader>e", actions.focus_files, { desc = "Bring focus to the file panel" } },
						{ "n", "<leader>b", actions.toggle_files, { desc = "Toggle the file panel" } },
						{ "n", "g<C-x>", actions.cycle_layout, { desc = "Cycle available layouts" } },
						{ "n", "[x", actions.prev_conflict, { desc = "Go to the previous conflict" } },
						{ "n", "]x", actions.next_conflict, { desc = "Go to the next conflict" } },
						{ "n", "g?", actions.help("file_panel"), { desc = "Open the help panel" } },
					},
					file_history_panel = {
						{ "n", "g!", actions.options, { desc = "Open the option panel" } },
						{
							"n",
							"<C-A-d>",
							actions.open_in_diffview,
							{ desc = "Open the entry under the cursor in a diffview" },
						},
						{
							"n",
							"y",
							actions.copy_hash,
							{ desc = "Copy the commit hash of the entry under the cursor" },
						},
						{ "n", "L", actions.open_commit_log, { desc = "Show commit details" } },
						{ "n", "zR", actions.open_all_folds, { desc = "Expand all folds" } },
						{ "n", "zM", actions.close_all_folds, { desc = "Collapse all folds" } },
						{ "n", "j", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
						{ "n", "<down>", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
						{ "n", "k", actions.prev_entry, { desc = "Bring the cursor to the previous file entry." } },
						{ "n", "<up>", actions.prev_entry, { desc = "Bring the cursor to the previous file entry." } },
						{ "n", "<cr>", actions.select_entry, { desc = "Open the diff for the selected entry." } },
						{ "n", "o", actions.select_entry, { desc = "Open the diff for the selected entry." } },
						{
							"n",
							"<2-LeftMouse>",
							actions.select_entry,
							{ desc = "Open the diff for the selected entry." },
						},
						{ "n", "<c-b>", actions.scroll_view(-0.25), { desc = "Scroll the view up" } },
						{ "n", "<c-f>", actions.scroll_view(0.25), { desc = "Scroll the view down" } },
						{ "n", "<tab>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
						{ "n", "<s-tab>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
						{
							"n",
							"gf",
							actions.goto_file,
							{ desc = "Open the file in a new split in the previous tabpage" },
						},
						{ "n", "<C-w><C-f>", actions.goto_file_split, { desc = "Open the file in a new split" } },
						{ "n", "<C-w>gf", actions.goto_file_tab, { desc = "Open the file in a new tabpage" } },
						{ "n", "<leader>e", actions.focus_files, { desc = "Bring focus to the file panel" } },
						{ "n", "<leader>b", actions.toggle_files, { desc = "Toggle the file panel" } },
						{ "n", "g<C-x>", actions.cycle_layout, { desc = "Cycle available layouts" } },
						{ "n", "g?", actions.help("file_history_panel"), { desc = "Open the help panel" } },
					},
					option_panel = {
						{ "n", "<tab>", actions.select_entry, { desc = "Change the current option" } },
						{ "n", "q", actions.close, { desc = "Close the panel" } },
						{ "n", "g?", actions.help("option_panel"), { desc = "Open the help panel" } },
					},
					help_panel = {
						{ "n", "q", actions.close, { desc = "Close help menu" } },
						{ "n", "<esc>", actions.close, { desc = "Close help menu" } },
					},
				},
			})
		end,
	},

	{
		"sQVe/sort.nvim",
		lazy = false,
		config = function()
			require("sort").setup({
				delimiters = {
					",",
					"|",
					";",
					":",
					"s", -- Space
					"t", -- Tab
				},
			})
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter-context",
		lazy = false,
		requires = "nvim-treesitter/nvim-treesitter",
		config = function()
			require("treesitter-context").setup({
				enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
				max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
				trim_scope = "outer", -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
				min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
				patterns = { -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
					-- For all filetypes
					-- Note that setting an entry here replaces all other patterns for this entry.
					-- By setting the 'default' entry below, you can control which nodes you want to
					-- appear in the context window.
					default = {
						"class",
						"function",
						"method",
						"for",
						"while",
						"if",
						"switch",
						"case",
						"interface",
						"struct",
						"enum",
					},
					-- Patterns for specific filetypes
					-- If a pattern is missing, *open a PR* so everyone can benefit.
					tex = {
						"chapter",
						"section",
						"subsection",
						"subsubsection",
					},
					haskell = {
						"adt",
					},
					rust = {
						"impl_item",
					},
					terraform = {
						"block",
						"object_elem",
						"attribute",
					},
					scala = {
						"object_definition",
					},
					vhdl = {
						"process_statement",
						"architecture_body",
						"entity_declaration",
					},
					markdown = {
						"section",
					},
					elixir = {
						"anonymous_function",
						"arguments",
						"block",
						"do_block",
						"list",
						"map",
						"tuple",
						"quoted_content",
					},
					json = {
						"pair",
					},
					typescript = {
						"export_statement",
					},
					yaml = {
						"block_mapping_pair",
					},
				},
				exact_patterns = {
					-- Example for a specific filetype with Lua patterns
					-- Treat patterns.rust as a Lua pattern (i.e "^impl_item$" will
					-- exactly match "impl_item" only)
					-- rust = true,
				},

				-- [!] The options below are exposed but shouldn't require your attention,
				--     you can safely ignore them.

				zindex = 20, -- The Z-index of the context window
				mode = "cursor", -- Line used to calculate context. Choices: 'cursor', 'topline'
				-- Separator between context and content. Should be a single character string, like '-'.
				-- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
				separator = nil,
			})
		end,
	},

	{
		"z0mbix/vim-shfmt",
		lazy = false,
		config = function()
			vim.g.shfmt_extra_args = "-i 2"
			vim.g.shfmt_fmt_on_save = 0
		end,
	},

	{
		"ray-x/lsp_signature.nvim",
		lazy = false,
	},
})

vim.cmd([[ colorscheme onedark ]])
vim.cmd([[ autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() != 'c' | checktime | endif ]])

-- vim.cmd([[
-- function! Format()
--     if (&ft=='typescript' || &ft=='typescriptreact' || &ft=='javascript' || &ft=='javascriptreact')
--       if ((filereadable('.eslintrc.js') || filereadable('.eslintrc.json')))
--         :EslintFixAll
--       else
--         :lua vim.lsp.buf.format()
--       endif
--     elseif (&ft=='nix')
--       let save_cursor = getcurpos()
--       :silent %!nixpkgs-fmt
--       call setpos('.', save_cursor)
--     elseif (&ft=='astro')
--       if (filereadable('prettier.config.mjs') || filereadable('prettier.config.cjs') || filereadable('prettier.config.js'))
--         let save_cursor = getcurpos()
--         :silent %!prettier --parser astro
--         call setpos('.', save_cursor)
--       endif
--     elseif (&ft=='sh')
--       :Shfmt
--     elseif (&ft=='lua')
--       :lua vim.lsp.buf.format()
--     endif
-- endfunction
--
-- autocmd BufWritePre * call Format()
-- ]])
