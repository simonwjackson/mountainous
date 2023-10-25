-- vim-shfmt.lua: A Vim/Neovim plugin to format shell script files using shfmt.

return {
	{
		"z0mbix/vim-shfmt",
		lazy = false,
		config = function()
			vim.g.shfmt_extra_args = "-i 2"
			vim.g.shfmt_fmt_on_save = 0
		end,
	},
}
