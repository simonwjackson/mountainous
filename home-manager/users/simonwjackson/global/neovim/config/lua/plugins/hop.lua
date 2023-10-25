-- An EasyMotion-like plugin allowing you to jump anywhere in a document with as few keystrokes as possible.
return {
	{
		"phaazon/hop.nvim",
		lazy = false,
		init = function()
			local hop = require("hop")
			local wk = require("which-key")

			hop.setup({
				keys = "fjdksla:ghrueiwoqpvmcnxbzty,.",
				multi_windows = true,
			})

			wk.register({
				j = {
					function()
						hop.hint_vertical({
							direction = require("hop.hint").HintDirection.AFTER_CURSOR,
						})
					end,
					"Hop down below cursor",
				},
				k = {
					function()
						hop.hint_vertical({
							direction = require("hop.hint").HintDirection.BEFORE_CURSOR,
						})
					end,
					"Hop up above cursor",
				},
				s = {
					function()
						hop.hint_char2()
					end,
					"Hop to word with 2 characters",
				},
			}, { mode = "v" })

			wk.register({
				s = {
					function()
						hop.hint_char2()
					end,
					"Hop to word with 2 characters",
				},
			}, { mode = "n" })

			wk.register({
				s = {
					function()
						hop.hint_char2()
					end,
					"Hop to word with 2 characters",
				},
				j = {
					function()
						hop.hint_vertical({
							direction = require("hop.hint").HintDirection.AFTER_CURSOR,
						})
					end,
					"Hop down below cursor",
				},
				k = {
					function()
						hop.hint_vertical({
							direction = require("hop.hint").HintDirection.BEFORE_CURSOR,
						})
					end,
					"Hop up above cursor",
				},
			}, { mode = "x" })
		end,
	},
}
