-- A small automated session manager for Neovim.
return {
	{
		"rmagatti/auto-session",
		lazy = false,
		opts = {
			log_level = "error",
			auto_session_suppress_dirs = { "~/", "~/downloads", "/" },
		},
	},
}
