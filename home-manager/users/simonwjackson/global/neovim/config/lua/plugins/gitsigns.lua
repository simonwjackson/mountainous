-- Git signs written in pure Lua

return {
	{
		"lewis6991/gitsigns.nvim",
		dependencies = {
			"folke/which-key.nvim",
		},
		config = function()
			local wk = require("which-key")

			require("gitsigns").setup({
				signs = {
					add = { text = "│" },
					change = { text = "│" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
					untracked = { text = "┆" },
				},
				signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
				numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
				linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
				word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
				watch_gitdir = {
					follow_files = true,
				},
				attach_to_untracked = true,
				current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
				current_line_blame_opts = {
					virt_text = true,
					virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
					delay = 1000,
					ignore_whitespace = false,
				},
				current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
				sign_priority = 6,
				update_debounce = 100,
				status_formatter = nil, -- Use default
				max_file_length = 40000, -- Disable if file is longer than this (in lines)
				preview_config = {
					-- Options passed to nvim_open_win
					border = "single",
					style = "minimal",
					relative = "cursor",
					row = 0,
					col = 1,
				},
				yadm = {
					enable = false,
				},
				on_attach = function(bufnr)
					local gs = package.loaded.gitsigns

					local function map(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = bufnr
						vim.keymap.set(mode, l, r, opts)
					end

					-- Navigation through hunks
					wk.register({
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

						["<leader>h"] = {
							name = "+gitsigns",
							s = { gs.stage_hunk, "Stage Hunk" },
							r = { gs.reset_hunk, "Reset Hunk" },
							S = { gs.stage_buffer, "Stage Buffer" },
							u = { gs.undo_stage_hunk, "Undo Stage Hunk" },
							R = { gs.reset_buffer, "Reset Buffer" },
							p = { gs.preview_hunk, "Preview Hunk" },
							b = {
								function()
									gs.blame_line({ full = true })
								end,
								"Blame Line",
							},
							d = { gs.diffthis, "Diff This" },
							D = {
								function()
									gs.diffthis("~")
								end,
								"Diff This (~)",
							},
							t = { gs.toggle_deleted, "Toggle Deleted" },
						},
					}, { mode = "n" })

					wk.register({
						["<leader>h"] = {
							s = {
								function()
									gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
								end,
								"Stage Hunk",
							},
							r = {
								function()
									gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
								end,
								"Reset Hunk",
							},
						},
					}, { mode = "v" })

					-- Text object
					wk.register({
						ih = ":<C-U>Gitsigns select_hunk<CR>",
					}, { mode = "o" })
					wk.register({
						ih = ":<C-U>Gitsigns select_hunk<CR>",
					}, { mode = "x" })
				end,
			})
		end,
	},
}
