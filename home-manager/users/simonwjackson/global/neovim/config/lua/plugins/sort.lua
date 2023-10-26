-- A simple sort utility for Neovim.

return {
	{
		"sQVe/sort.nvim",
		lazy = false,
		opts = {
			delimiters = {
				",",
				"|",
				";",
				":",
				"s", -- Space
				"t", -- Tab
			},
		},
	},
}
