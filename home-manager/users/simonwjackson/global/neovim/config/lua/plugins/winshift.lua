-- Window management for Neovim: move and resize windows using visual selection or directional keys.

return {
	{
		"sindrets/winshift.nvim",
		lazy = false,
		config = function()
			require("winshift").setup({
				keymaps = {
					disable_defaults = true, -- Disable the default keymaps
				},
			})
		end,
	},
}
