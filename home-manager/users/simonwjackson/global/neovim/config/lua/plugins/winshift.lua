-- Window management for Neovim: move and resize windows using visual selection or directional keys.

return {
	{
		"sindrets/winshift.nvim",
		keys = {
			{ "<C-M-h>", "<Cmd>WinShift left<CR>", desc = "Move window left" },
			{ "<C-M-j>", "<Cmd>WinShift down<CR>", desc = "Move window down" },
			{ "<C-M-k>", "<Cmd>WinShift up<CR>", desc = "Move window up" },
			{ "<C-M-l>", "<Cmd>WinShift right<CR>", desc = "Move window right" },
		},
		opts = {
			highlight_moving_win = true, -- Highlight the window being moved
			focused_hl_group = "Visual", -- The highlight group used for the moving window
			moving_win_options = {
				-- These are local options applied to the moving window while it's
				-- being moved. They are unset when you leave Win-Move mode.
				wrap = true,
				cursorline = false,
				cursorcolumn = false,
				colorcolumn = "",
			},
			keymaps = {
				disable_defaults = true,
			},
		},
	},
}
