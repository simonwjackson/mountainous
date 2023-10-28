return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
		},
		event = { "BufReadPre", "BufNewFile" },
		init = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			require("lspconfig").vimls.setup({
				capabilities = capabilities,
			})
			require("lspconfig").nixd.setup({
				capabilities = capabilities,
			})
			require("lspconfig").bashls.setup({
				capabilities = capabilities,
			})
			require("lspconfig").tsserver.setup({
				capabilities = capabilities,
			})
			require("lspconfig").graphql.setup({
				capabilities = capabilities,
			})
			require("lspconfig").tailwindcss.setup({
				capabilities = capabilities,
			})
			-- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers..

			require("lspconfig").lua_ls.setup({
				capabilities = capabilities,
				on_init = function(client)
					local path = client.workspace_folders[1].name
					if
						not vim.loop.fs_stat(path .. "/.luarc.json") and not vim.loop.fs_stat(path .. "/.luarc.jsonc")
					then
						client.config.settings = vim.tbl_deep_extend("force", client.config.settings, {
							Lua = {
								runtime = {
									-- Tell the language server which version of Lua you're using
									-- (most likely LuaJIT in the case of Neovim)
									version = "LuaJIT",
								},
								-- Make the server aware of Neovim runtime files
								workspace = {
									checkThirdParty = false,
									library = {
										vim.env.VIMRUNTIME,
										-- "${3rd}/luv/library"
										-- "${3rd}/busted/library",
									},
									-- or pull in all of 'runtimepath'. NOTE: this is a lot slower
									-- library = vim.api.nvim_get_runtime_file("", true)
								},
							},
						})

						client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
					end

					return true
				end,
			})
		end,
	},

	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-nvim-lua",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-nvim-lsp-signature-help",
			"onsails/lspkind.nvim",
			"kristijanhusak/vim-dadbod-completion",
			"ray-x/cmp-treesitter",
			"f3fora/cmp-spell",
			"hrsh7th/cmp-emoji",
			"hrsh7th/cmp-calc",
			"David-Kunz/cmp-npm",
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",
			"zbirenbaum/copilot-cmp",
		},
		init = function()
			local cmp = require("cmp")
			local lspkind = require("lspkind")
			require("copilot_cmp").setup()

			vim.opt.completeopt = { "menu", "menuone", "noselect" }

			cmp.setup({
				formatting = {
					format = lspkind.cmp_format({
						symbol_map = { Copilot = "" },
						mode = "symbol", -- show only symbol annotations
						-- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
						maxwidth = 50,
						-- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)
						ellipsis_char = "...",
						-- The function below will be called before any actual modifications from lspkind
						-- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
						before = function(_, vim_item)
							return vim_item
						end,
					}),
				},
				snippet = {
					expand = function(args)
						require("luasnip").lsp_expand(args.body)
					end,
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				mapping = cmp.mapping.preset.insert({
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					-- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
					["<CR>"] = cmp.mapping.confirm({ select = true }),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp_signature_help", group_index = 2 },
					{ name = "nvim_lsp", group_index = 2 },
					{ name = "treesitter", group_index = 2 },
					{
						name = "spell",
						group_index = 2,
						option = {
							keep_all_entries = false,
							enable_in_context = function()
								return true
							end,
						},
					},
					{ name = "copilot", group_index = 2 },
				}, {
					{ name = "buffer" },
					{ name = "nvim_lua" },
					{ name = "path" },
					{ name = "vim-dadbod-completion" },
					{ name = "emoji" },
					{ name = "calc" },
					{ name = "npm", keyword_length = 4 },
				}),
			})

			-- Set configuration for specific filetype.
			cmp.setup.filetype("gitcommit", {
				sources = cmp.config.sources({
					{ name = "git" }, -- You can specify the `git` source if [you were installed it](https://github.com/petertriho/cmp-git).
				}, {
					{ name = "buffer" },
				}),
			})

			-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
			cmp.setup.cmdline({ "/", "?" }, {
				mapping = cmp.mapping.preset.cmdline(),
				sources = {
					{ name = "buffer" },
				},
			})

			cmp.setup.cmdline(":", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{
						name = "cmdline",
						option = {
							ignore_cmds = { "Man", "!" },
						},
					},
				}),
			})
		end,
	},
}
