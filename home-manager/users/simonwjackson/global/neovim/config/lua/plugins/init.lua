local opt = vim.opt
local g = vim.g
local api = vim.api
local cmd = vim.api.nvim_command

return {
	{ "rose-pine/neovim", name = "rose-pine" },

	-- Floating terminal plugin for Vim
	{
		"voldikss/vim-floaterm",
	},

	-- Vim sugar for the UNIX shell commands
	{ "tpope/vim-eunuch" },

	-- Start a * or # search from a visual selection
	{ "nelstrom/vim-visual-star-search" },

	-- Visually select increasingly larger regions of text
	{ "terryma/vim-expand-region" },

	-- Incremental search improved in Vim
	{ "haya14busa/is.vim", lazy = false },

	-- Neovim configuration helper
	{ "folke/neoconf.nvim", cmd = "Neoconf" },

	-- Neovim development helper
	{ "folke/neodev.nvim" },

	-- Mason's LSP configuration for Neovim
	{ "williamboman/mason-lspconfig.nvim" },

	-- Quickstart configurations for the Nvim LSP client
	{ "neovim/nvim-lspconfig" },
	--
	-- Show function signature when you type
	{
		"ray-x/lsp_signature.nvim",
		lazy = false,
	},

	-- Syntax highlighting and indentation for MDX (Markdown + JSX)
	{
		ft = "markdown.mdx",
		"jxnblk/vim-mdx-js",
	},

	-- Surroundings in Neovim with ease
	{
		"kylechui/nvim-surround",
		lazy = false,
		config = function()
			-- require("plugins.configs.")
		end,
	},

	-- A dark One Color Scheme for Neovim >0.5 written in Lua.
	{
		"navarasu/onedark.nvim",
		init = function()
			require("onedark").setup({
				-- Main options --
				-- Default theme style. Choose between 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer' and 'light'
				style = "cool",
				transparent = true, -- Show/hide background
				term_colors = true, -- Change terminal color as per the selected theme style
				ending_tildes = false, -- Show the end-of-buffer tildes. By default they are hidden
				cmp_itemkind_reverse = false, -- reverse item kind highlights in cmp menu

				-- Lualine options --
				lualine = {
					transparent = true, -- lualine center bar transparency
				},

				-- Custom Highlights --
				colors = {}, -- Override default colors
				highlights = {}, -- Override highlight groups

				-- Plugins Config --
				diagnostics = {
					darker = true, -- darker colors for diagnostic
					undercurl = true, -- use undercurl instead of underline for diagnostics
					background = true, -- use background color for virtual text
				},
			})
		end,
	},
}

-- {
--   "zbirenbaum/copilot-cmp",
--   after = { "copilot.lua" },
--   lazy = false,
--   config = function()
--     require("copilot_cmp").setup({})
--   end,
-- },

-- { "lukas-reineke/indent-blankline.nvim" },
