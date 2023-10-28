-- It is recommended to disable copilot.lua's suggestion and panel modules, as they can interfere with completions
-- properly appearing in copilot-cmp. To do so, simply place the following in your copilot.lua config:

return {
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		opts = {
			panel = {
				enabled = false,
				auto_refresh = false,
				keymap = {
					jump_prev = "[[",
					jump_next = "]]",
					accept = "<CR>",
					refresh = "gr",
					open = "<M-CR>",
				},
				layout = {
					position = "bottom", -- | top | left | right
					ratio = 0.4,
				},
			},

			suggestion = {
				enabled = false,
				auto_trigger = false,
				debounce = 75,
				keymap = {
					accept = "<M-l>",
					accept_word = false,
					accept_line = false,
					next = "<M-]>",
					prev = "<M-[>",
					dismiss = "<C-]>",
				},
			},
			filetypes = {
				markdown = true, -- overrides default
				yaml = false,
				help = false,
				gitcommit = false,
				gitrebase = false,
				hgcommit = false,
				svn = false,
				cvs = false,
				["."] = false,
				sh = function()
					if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), "^%.env.*") then
						-- disable for .env files
						return false
					end
					return true
				end,
			},
			copilot_node_command = "node", -- Node.js version must be > 16.x
			server_opts_overrides = {},
		},
		event = { "InsertEnter" },
		lazy = false,
		config = function(_, opts)
			require("copilot").setup(opts)
			-- require("copilot").setup({
			-- 	suggestion = { enabled = false },
			-- 	panel = { enabled = false },
			-- })
		end,
	},
}
