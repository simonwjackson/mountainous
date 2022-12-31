-- place this in one of your configuration file(s)
local hop = require('hop')
local wk = require("which-key")

hop.setup {
  keys = 'fjdksla:ghrueiwoqpvmcnxbzty,.',
  multi_windows = true,
}

wk.register({
  j = { function() hop.hint_lines_skip_whitespace({
      direction = require 'hop.hint'.HintDirection.AFTER_CURSOR,
    })
  end, "Hop down below cursor" },
  k = { function() hop.hint_lines_skip_whitespace({
      direction = require 'hop.hint'.HintDirection.BEFORE_CURSOR,
    })
  end, "Hop up above cursor" },
  s = { function() hop.hint_char2() end, "Hop to word with 2 characters" },
}, { mode = "v" })

wk.register({
  s = { function() hop.hint_char2() end, "Hop to word with 2 characters" },
}, { mode = "n" })

wk.register({
  s = { function() hop.hint_char2() end, "Hop to word with 2 characters" },
}, { mode = "x" })

wk.register({
  s = { function() hop.hint_char2() end, "Hop to word with 2 characters" },
  D = {
    "V<cmd>HopLine<cr>",
    "Action to character",
    noremap = true
  },
}, { mode = "o" })


-- Move to own file
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

  winblend = 0, -- psuedotransparency level
  dir = "", -- directory where `lf` starts ('gwd' is git-working-directory, "" is CWD)
  direction = "float", -- window type: float horizontal vertical
  border = "curved", -- border kind: single double shadow curved
  height = 0.80, -- height of the *floating* window
  width = 0.85, -- width of the *floating* window
  escape_quit = true, -- map escape to the quit command (so it doesn't go into a meta normal mode)
  focus_on_open = true, -- focus the current file when opening Lf (experimental)
  mappings = true, -- whether terminal buffer mapping is enabled
  tmux = false, -- tmux statusline can be disabled on opening of Lf
  highlights = {
    -- highlights passed to toggleterm
    -- Normal = { guibg = <VALUE> },
    NormalFloat = { link = 'Normal' },
    FloatBorder = {
      guifg = require("dracula").colors().comment,
    }
  },

  -- Layout configurations
  layout_mapping = "<A-u>", -- resize window with this key
})

wk.register({
  ["<F9>"] = { "<cmd>Lf<cr>", "Hop to word with 2 characters" },
})
