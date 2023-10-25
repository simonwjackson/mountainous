-- An asynchronous linter plugin for Neovim 0.5 using the built-in LSP functionality.

return {
	{
		"mfussenegger/nvim-lint",
		init = function()
			require("lint").linters_by_ft = {
				markdown = { "vale" },
				lua = { "luacheck" },
				-- typescript = { "eslint_d" },
				-- javascript = { "eslint_d" },
				-- typescriptreact = { "eslint_d" },
				json = { "jsonlint" },
				nix = { "nix" },
				yaml = { "yamllint" },
				vim = { "vint" },
			}
			vim.api.nvim_create_autocmd({ "VimEnter", "TextChanged" }, {
				callback = function()
					require("lint").try_lint()
				end,
			})
		end,
	},
}
