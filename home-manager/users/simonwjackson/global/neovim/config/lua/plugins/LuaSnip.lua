return {
	{
		"L3MON4D3/LuaSnip",
		dependencies = {
			"folke/which-key.nvim",
		},
		-- follow latest release.
		version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
		-- install jsregexp (optional!).
		build = "make install_jsregexp",
		init = function()
			local ls = require("luasnip")
			local wk = require("which-key")

			wk.register(
				{ ["<C-K>"] = {
					function()
						ls.expand()
					end,
					"Expand",
				} },
				{ mode = "i", silent = true }
			)

			wk.register({
				["<C-L>"] = {
					function()
						ls.jump(1)
					end,
					"Jump Forward",
				},
				["<C-J>"] = {
					function()
						ls.jump(-1)
					end,
					"Jump Backward",
				},
				["<C-E>"] = {
					function()
						if ls.choice_active() then
							ls.change_choice(1)
						end
					end,
					"Change Choice",
				},
			}, { mode = "s", silent = true })
		end,
	},
}
