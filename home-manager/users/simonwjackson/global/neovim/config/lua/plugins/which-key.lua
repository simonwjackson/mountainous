--
-- {
--   "folke/which-key.nvim",
--   event = "VeryLazy",
--   opts = {
--     plugins = { spelling = true },
--     key_labels = { ["<leader>"] = "SPC" },
--   },
--   config = function(_, opts)
--     local wk = require("which-key")
--     wk.setup(opts)
--     wk.register({
--       mode = { "n", "v" },
--       ["g"] = { name = "+goto" },
--       ["]"] = { name = "+next" },
--       ["["] = { name = "+prev" },
--       ["<leader><tab>"] = { name = "+tabs" },
--       ["<leader>b"] = { name = "+buffer" },
--       ["<leader>c"] = { name = "+code" },
--       ["<leader>f"] = { name = "+file/find" },
--       ["<leader>g"] = { name = "+git" },
--       ["<leader>gh"] = { name = "+hunks" },
--       ["<leader>q"] = { name = "+quit/session" },
--       ["<leader>s"] = { name = "+search" },
--       ["<leader>sn"] = { name = "+noice" },
--       ["<leader>u"] = { name = "+ui" },
--       ["<leader>w"] = { name = "+windows" },
--       ["<leader>x"] = { name = "+diagnostics/quickfix" },
--     })
--   end,
-- },
local cmd = vim.api.nvim_command
-- This is a lua version of vim which key that displays available keybindings in popup menu.

return {
	{
		"folke/which-key.nvim",
		init = function()
			local wk = require("which-key")

			local function my_lazygit()
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
				["<leader>gg"] = { my_lazygit, "Open lazygit", opts = { nowait = true } },
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

				-- ["gi"] = {
				--   function()
				--     vim.lsp.buf.implementation()
				--   end,
				--   "LSP implementation",
				-- },
				--
				-- ["<leader>ls"] = {
				--   function()
				--     vim.lsp.buf.signature_help()
				--   end,
				--   "LSP signature help",
				-- },
				--
				-- ["<leader>D"] = {
				--   function()
				--     vim.lsp.buf.type_definition()
				--   end,
				--   "LSP definition type",
				-- },
				--
				-- ["<leader>ra"] = {
				--   function()
				--     require("nvchad_ui.renamer").open()
				--   end,
				--   "LSP rename",
				-- },
				--
				-- ["<leader>ca"] = {
				--   function()
				--     vim.lsp.buf.code_action()
				--   end,
				--   "LSP code action",
				-- },
				--
				-- ["gr"] = {
				--   function()
				--     vim.lsp.buf.references()
				--   end,
				--   "LSP references",
				-- },
				--
				-- ["<leader>f"] = {
				--   function()
				--     vim.diagnostic.open_float({ border = "rounded" })
				--   end,
				--   "Floating diagnostic",
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
				["<C-s>"] = { ":write<CR>", "Save file (if modified)" },

				-- Allow moving the cursor through wrapped lines with j, k, <Up> and <Down>
				-- http://www.reddit.com/r/vim/comments/2k4cbr/problem_with_gj_and_gk/
				-- empty mode is same as using <cmd> :map
				-- also don't use g[j|k] when in operator pending mode, so it doesn't alter d, y or c behaviour

				["j"] = {
					function()
						vim.api.nvim_exec(vim.v.count == 0 and "normal! gj" or "normal! j", false)
					end,
					"Move up",
					opts = { expr = true },
				},
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
}
