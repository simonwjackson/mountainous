-- A simple wrapper around git worktree operations, create, switch, and delete

return {
	{
		"ThePrimeagen/git-worktree.nvim",
		keys = {
			{
				"<F11>",
				"<cmd>lua require('telescope').extensions.git_worktree.git_worktrees()<cr>",
				desc = "List worktrees",
			},
			{
				"<F12>",
				"<cmd>lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>",
				desc = "Create worktree",
			},
		},
		dependencies = {
			"folke/which-key.nvim",
			"plenary.nvim",
			"nvim-telescope/telescope.nvim",
		},
	},
}
