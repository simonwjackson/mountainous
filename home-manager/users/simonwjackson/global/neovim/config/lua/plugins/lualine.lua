-- A statusline plugin written for neovim. It’s primarily written in lua.

local function host()
	local f = io.popen("/run/current-system/sw/bin/hostname")
	local hostname = f:read("*a") or ""
	f:close()
	hostname = string.gsub(hostname, "\n$", "")
	return hostname
end

local function tmux_session()
	local cmd = "tmux display-message -p '#S'"
	local session = vim.fn.system(cmd)
	if session then
		session = string.gsub(session, "\n$", "")
		return session
	end
	return ""
end

return {
	{
		"nvim-lualine/lualine.nvim",
		lazy = false,
		config = function()
			vim.g.my_global_var = true

			local tabs = {
				"tabs",
				max_length = vim.o.columns / 3, -- Maximum width of tabs component.
				-- Note:
				-- It can also be a function that returns
				-- the value of `max_length` dynamically.
				mode = 2, -- 0: Shows tab_nr
				-- 1: Shows tab_name
				-- 2: Shows tab_nr + tab_name

				-- Automatically updates active tab color to match color of other components (will be overidden if buffers_color is set)
				use_mode_colors = false,
				tabs_color = {
					-- Same values as the general color option can be used here.
					-- active = 'lualine_{section}_normal',     -- Color for active tab.
					-- inactive = 'lualine_{section}_inactive', -- Color for inactive tab.
				},

				fmt = function(name, context)
					-- Show + if buffer is modified in tab
					local buflist = vim.fn.tabpagebuflist(context.tabnr)
					local winnr = vim.fn.tabpagewinnr(context.tabnr)
					local bufnr = buflist[winnr]
					local mod = vim.fn.getbufvar(bufnr, "&mod")

					return name .. (mod == 1 and " +" or "")
				end,
			}

			require("lualine").setup({
				options = {
					icons_enabled = true,
					theme = "onedark",
					component_separators = { left = "", right = "" },
					section_separators = { left = "", right = "" },
					disabled_filetypes = {
						statusline = {},
						winbar = {},
					},
					ignore_focus = {},
					always_divide_middle = false,
					globalstatus = true,
					refresh = {
						statusline = 1000,
						tabline = 1000,
						winbar = 1000,
					},
				},
				sections = {
					lualine_a = { tmux_session, "mode" },
					lualine_b = { "branch", "diff", "diagnostics" },
					lualine_c = { "filename" },

					lualine_x = { tabs },
					lualine_y = {
						-- "progress"
					},
					lualine_z = { "location", host },
				},
				inactive_sections = {
					lualine_a = {},
					lualine_b = {},
					lualine_c = { "filename" },
					lualine_x = { "location" },
					lualine_y = {},
					lualine_z = {},
				},
				tabline = {},
				winbar = {},
				inactive_winbar = {},
				extensions = {},
			})
		end,
	},
}
