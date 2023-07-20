require('coverage').setup({
  auto_reload = true,
  load_coverage_cb = function(ftype)
    vim.notify("Loaded " .. ftype .. " coverage")
  end,
  highlights = {
    -- hide covered
    -- BUG: This doesn't work when changing the colorscheme
    -- covered = { fg = require("dracula").colors().bg }
  },
  signs = {
    -- customize signs
  },
  summary = {
    -- customize summary pop-up
  },
  lang = {
    -- customize langauge specific settings
  }
})
