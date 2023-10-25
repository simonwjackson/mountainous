-- A simple wrapper around git worktree operations, create, switch, and delete

return {
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
}
