local wk = require("which-key")

wk.register({
  ["<F11>"] = { "<cmd>lua require('telescope').extensions.git_worktree.git_worktrees()<cr>", "List worktrees" },
  ["<F12>"] = { "<cmd>lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>", "Create worktree" },
})
