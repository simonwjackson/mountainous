local M = {}

M.treesitter = {
	ensure_installed = {
		"astro",
		"bash",
		"c",
		"css",
		"diff",
		"dockerfile",
		"git_config",
		"git_rebase",
		"gitattributes",
		"gitcommit",
		"gitignore",
		"haskell",
		"html",
		"http",
		"ini",
		"javascript",
		"jq",
		"jsdoc",
		"json",
		"json5",
		"jsonc",
		"lua",
		"markdown",
		"markdown_inline",
		"ocaml",
		"python",
		"regex",
		"scss",
		"sql",
		-- "svelte",
		"sxhkdrc",
		"toml",
		"tsx",
		"typescript",
		"vim",
		"vue",
		"yaml",
	},
	indent = {
		enable = true,
		-- disable = {
		--   "python"
		-- },
	},
}

M.ui = {
	enabled = false,
}

M.mason = {
	ensure_installed = {
		-- lua stuff
		"lua-language-server",
		"stylua",

		-- web dev stuff
		"css-lsp",
		"html-lsp",
		"typescript-language-server",
		"deno",
		"prettier",

		-- c/cpp stuff
		"clangd",
		"clang-format",
	},
}

-- git support in nvimtree
M.nvimtree = {
	git = {
		enable = true,
	},

	renderer = {
		highlight_git = true,
		icons = {
			show = {
				git = true,
			},
		},
	},
}

return M
