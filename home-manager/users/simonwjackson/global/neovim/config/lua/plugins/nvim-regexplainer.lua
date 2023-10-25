-- A plugin that explains your regex patterns in a human-readable way.

return {
	{
		"bennypowers/nvim-regexplainer",
		lazy = false,
		config = function()
			require("regexplainer").setup({
				mode = "narrative",
				auto = true,
				-- filetypes (i.e. extensions) in which to run the autocommand
				filetypes = {
					"html",
					"js",
					"cjs",
					"mjs",
					"ts",
					"jsx",
					"tsx",
					"cjsx",
					"mjsx",
				},
				-- Whether to log debug messages
				debug = false,
				-- 'split', 'popup'
				display = "popup",
				mappings = {
					toggle = "gR",
					-- examples, not defaults:
					-- show = 'gS',
					-- hide = 'gH',
					-- show_split = 'gP',
					-- show_popup = 'gU',
				},
				narrative = {
					separator = "\n",
				},
			})
		end,
		requires = {
			"nvim-treesitter/nvim-treesitter",
			"MunifTanjim/nui.nvim",
		},
	},
}
