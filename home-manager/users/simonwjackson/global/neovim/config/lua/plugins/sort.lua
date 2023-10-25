-- A simple sort utility for Neovim.

return {
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
}
