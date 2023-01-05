local wk = require("which-key")
require("lf").setup({
  default_cmd = "lf", -- default `lf` command
  default_action = "edit", -- default action when `Lf` opens a file
  default_actions = {
    -- default action keybindings
    ["<C-t>"] = "tabedit",
    ["<C-x>"] = "split",
    ["<C-v>"] = "vsplit",
    ["<C-o>"] = "tab drop",
  },

  winblend = 10, -- psuedotransparency level
  dir = "", -- directory where `lf` starts ('gwd' is git-working-directory, "" is CWD)
  direction = "float", -- window type: float horizontal vertical
  border = "single", -- border kind: single double shadow curved
  height = 0.80, -- height of the *floating* window
  width = 0.85, -- width of the *floating* window
  escape_quit = true, -- map escape to the quit command (so it doesn't go into a meta normal mode)
  focus_on_open = false, -- focus the current file when opening Lf (experimental)
  mappings = true, -- whether terminal buffer mapping is enabled
  tmux = false, -- tmux statusline can be disabled on opening of Lf
  -- highlights passed to toggleterm
  highlights = {
    -- Normal = { guibg = <VALUE> },
    NormalFloat = { link = 'Normal' },
    FloatBorder = {
      guifg = require("dracula").colors().comment,
    }
  },
  -- Layout configurations
  -- resize window with this key
  layout_mapping = "<A-u>",

  views = { -- window dimensions to rotate through
    { width = 0.600, height = 0.600 },
    -- {
    --   width = 1.0 * vim.fn.float2nr(fn.round(0.7 * o.columns)) / o.columns,
    --   height = 1.0 * vim.fn.float2nr(fn.round(0.7 * o.lines)) / o.lines,
    -- },
    { width = 0.800, height = 0.800 },
    { width = 0.950, height = 0.950 },
  }
})

wk.register({
  ["<F9>"] = { "<cmd>Lf<cr>", "Hop to word with 2 characters" },
})
