-- A terminal emulator for Neovim with first class terminal and job support.

return {
	{
		"NvChad/nvterm",
		keys = {
			{
				"<A-C-.>",
				function()
					require("nvterm.terminal").toggle("vertical")
				end,
				mode = { "n", "t", "x", "v" },
				desc = "Vertical Split Terminal",
			},
			{
				"<A-.>",
				function()
					require("nvterm.terminal").toggle("horizontal")
				end,
				mode = { "n", "t", "x", "v" },
				desc = "Vertical Split Terminal",
			},
		},
		opts = {
			terminals = {
				shell = vim.o.shell,
				list = {},
				type_opts = {
					float = {
						relative = "editor",
						row = 0.3,
						col = 0.25,
						width = 0.5,
						height = 0.4,
						border = "single",
					},
					horizontal = { location = "rightbelow", split_ratio = 0.3 },
					vertical = { location = "rightbelow", split_ratio = 0.5 },
				},
			},
			behavior = {
				autoclose_on_quit = {
					enabled = false,
					confirm = false,
				},
				close_on_exit = true,
				auto_insert = true,
			},
		},
	},
}
