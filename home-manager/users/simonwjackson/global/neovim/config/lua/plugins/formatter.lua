-- A format runner for Neovim.

local ecma = {
	function()
		return {
			exe = "prettier",
			args = {
				"--config-precedence",
				"prefer-file",
				"--stdin-filepath",
				vim.fn.shellescape(vim.api.nvim_buf_get_name(0)),
			},
			stdin = true,
		}
	end,
	function()
		return {
			exe = "eslint_d",
			args = {
				"--stdin",
				"--stdin-filename",
				vim.api.nvim_buf_get_name(0),
				"--fix-to-stdout",
			},
			stdin = true,
		}
	end,
}

return {
	{
		"mhartington/formatter.nvim",
		init = function()
			vim.api.nvim_command([[
        augroup FormatAutogroup
        autocmd!
          autocmd BufWritePost * FormatWrite
          augroup END
      ]])
			-- Utilities for creating configurations
			local util = require("formatter.util")

			-- Provides the Format, FormatWrite, FormatLock, and FormatWriteLock commands
			require("formatter").setup({
				-- Enable or disable logging
				logging = true,
				-- Set the log level
				log_level = vim.log.levels.WARN,
				-- All formatter configurations are opt-in
				filetype = {
					-- Formatter configurations for filetype "lua" go here
					-- and will be executed in order
					lua = {
						-- "formatter.filetypes.lua" defines default configurations for the
						-- "lua" filetype
						require("formatter.filetypes.lua").stylua,
					},

					nix = {
						-- "formatter.filetypes.lua" defines default configurations for the
						-- "lua" filetype
						require("formatter.filetypes.nix").alejandra,
					},

					sh = {
						require("formatter.filetypes.sh").shfmt,
					},

					typescript = ecma,
					typescriptreact = ecma,
					javascript = ecma,
					javascriptreact = ecma,

					-- Use the special "*" filetype for defining formatter configurations on
					-- any filetype
					["*"] = {
						-- "formatter.filetypes.any" defines default configurations for any
						-- filetype
						require("formatter.filetypes.any").remove_trailing_whitespace,
					},
				},
			})
		end,
	},
}
