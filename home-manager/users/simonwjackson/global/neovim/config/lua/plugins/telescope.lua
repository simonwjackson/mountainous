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
		lazy = false,
		keys = {
			{
				"<leader>fe",
				function()
					OpenLfInFloaterm()
				end,
				desc = "File Explorer",
			},
			{
				"<leader>fn",
				"<cmd>enew<cr>",
				desc = "New File",
			},
			{
				"<leader>ff",
				"<cmd> Telescope find_files <CR>",
				desc = "Find files",
			},
			{
				"<leader>fa",
				"<cmd> Telescope find_files follow=true no_ignore=true hidden=true <CR>",
				desc = "Find all",
			},
			{
				"<leader>fw",
				"<cmd> Telescope live_grep <CR>",
				desc = "Live grep",
			},
			{
				"<leader>fB",
				"<cmd> Telescope buffers <CR>",
				desc = "Find buffers",
			},
			{
				"<leader>fb",
				"<cmd> Telescope live_grep grep_open_files=true prompt_title=Find\\ in\\ Buffers <CR>",
				desc = "Find in buffers",
			},
			{
				"<leader>fh",
				"<cmd> Telescope help_tags <CR>",
				desc = "Help page",
			},
			{
				"<leader>fo",
				"<cmd> Telescope oldfiles <CR>",
				desc = "Find oldfiles",
			},
			{
				"<leader>fz",
				"<cmd> Telescope current_buffer_fuzzy_find <CR>",
				desc = "Find in current buffer",
			},
			{
				"<leader>cm",
				"<cmd> Telescope git_commits <CR>",
				desc = "Git commits",
			},
			{
				"<leader>gt",
				"<cmd> Telescope git_status <CR>",
				desc = "Git status",
			},

			-- TODO: Move these to which-key
			-- wk.register({
			-- 	["<leader>f"] = { name = "+file" },
			-- })
			{
				"<leader>wK",
				function()
					vim.cmd("WhichKey")
				end,
				desc = "Which-key all keymaps",
			},
			{
				"<leader>wk",
				function()
					local input = vim.fn.input("WhichKey: ")
					vim.cmd("WhichKey " .. input)
				end,
				desc = "Which-key query lookup",
			},
			{
				"<leader>jl",
				":FloatermNew --name=journallog --title=journal:log --height=1 journal log<cr>",
				desc = "Journal: Log",
			},
			{
				"<leader>jt",
				":FloatermNew --name=journaltask --title=journal:task --height=1 journal task<cr>",
				desc = "Journal: Task",
			},
		},
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
