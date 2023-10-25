-- A highly extendable fuzzy finder over lists that is based on the Lua programming language and the Telescope picker.

function OpenLfInFloaterm()
	local path = vim.fn.shellescape(vim.fn.fnamemodify(vim.fn.expand("%:p"), ":!"))

	vim.cmd(
		"FloatermNew --title=Files --name=files --height=0.75 --width=0.75 --wintype=float $SHELL -c 'lf "
			.. path
			.. "'"
	)
end

return {
	{
		"nvim-telescope/telescope.nvim",
		init = function()
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
}
