---@type MappingsTable
local M = {}

M.general = {
	v = {},
  n = {
  --   [";"] = { ":", "enter command mode", opts = { nowait = true } },
    ["<F6>"] = { ":tabnew | execute 'LualineRenameTab LazyGit' | term nvr -c 'terminal lazygit' -c 'startinsert' '+let g:auto_session_enabled = v:false'<CR>", "Open lazygit", opts = { nowait = true } },
    ["<A-s>"] = { ":silent! !tmux choose-tree<cr>", "show tmux sessions", opts = { nowait = true } },
    ["<A-1>"] = { ":silent! tabn 1<cr>", "Go to tab 1", opts = { nowait = true } },
    ["<A-2>"] = { ":silent! tabn 2<cr>", "Go to tab 2", opts = { nowait = true } },
    ["<A-3>"] = { ":silent! tabn 3<cr>", "Go to tab 3", opts = { nowait = true } },
    ["<A-4>"] = { ":silent! tabn 4<cr>", "Go to tab 4", opts = { nowait = true } },
    ["<A-5>"] = { ":silent! tabn 5<cr>", "Go to tab 5", opts = { nowait = true } },
    ["<A-6>"] = { ":silent! tabn 6<cr>", "Go to tab 6", opts = { nowait = true } },
    ["<A-7>"] = { ":silent! tabn 7<cr>", "Go to tab 7", opts = { nowait = true } },
    ["<A-8>"] = { ":silent! tabn 8<cr>", "Go to tab 8", opts = { nowait = true } },
    ["<A-9>"] = { ":silent! tabn 9<cr>", "Go to tab 9", opts = { nowait = true } },
  },

  t = {
    -- ["<Esc>"] = { "<Esc>", "Escape Term", opts = { nowait = true } },
    -- ["<C-Esc>"] = { "<C-\\><C-n>", "Term Normal Mode", opts = { nowait = true } },
    ["<A-s>"] = { "<C-\\><C-n>:silent! !tmux choose-tree<cr>", "show tmux sessions", opts = { nowait = true } },
  }
}

-- vim.api.nvim_set_keymap('t', '<C-Esc>', '<Esc>', { noremap = true })
vim.api.nvim_set_keymap('t', '<C-x>', '<Esc>', { noremap = true })
vim.api.nvim_set_keymap('t', '<C-Esc>', '<C-\\><C-n>', { noremap = true })
vim.api.nvim_set_keymap('t', '<A-Esc>', '<C-\\><C-n>', { noremap = true })

return M
