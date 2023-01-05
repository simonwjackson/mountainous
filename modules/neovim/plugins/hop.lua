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
