-- Vimwiki with tasks, powered by TaskWarrior.

local g = vim.g

return {
	{
		"tools-life/taskwiki",
		lazy = false,
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
}
