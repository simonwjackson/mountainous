local wk = require("which-key")
-- local actions = require("telescope.actions")
-- local trouble = require("trouble.providers.telescope")
-- local telescope = require("telescope")

local mappings = {
  ["<F7>"] = { "<cmd>lua Project_Files()<cr>", "Project Files" },
}

vim.api.nvim_set_keymap('t', '<C-Esc>', '<Esc>', { noremap = true })
vim.api.nvim_set_keymap('t', '<Esc>', '<C-\\><C-n>', { noremap = true })


local options = {
  plugins = {
    marks = true,       -- shows a list of your marks on ' and `
    registers = true,   -- shows your registers on " in NORMAL or <C-r> in INSERT mode
    spelling = {
      enabled = false,  -- enabling this will show WhichKey when pressing z= to select spelling suggestions
      suggestions = 20, -- how many suggestions should be shown in the list?
    },
    -- the presets plugin, adds help for a bunch of default keybindings in Neovim
    -- No actual key bindings are created
    presets = {
      operators = true,    -- adds help for operators like d, y, ... and registers them for motion / text object completion
      motions = true,      -- adds help for motions
      text_objects = true, -- help for text objects triggered after entering an operator
      windows = true,      -- default bindings on <c-w>
      nav = true,          -- misc bindings to work with windows
      z = true,            -- bindings for folds, spelling and others prefixed with z
      g = true,            -- bindings for prefixed with g
    },
  },
  -- add operators that will trigger motion and text object completion
  -- to enable all native operators, set the preset / operators plugin above
  operators = { gc = "Comments" },
  key_labels = {
    -- override the label used to display some keys. It doesn't effect WK in any other way.
    -- For example:
    -- ["<space>"] = "SPC",
    -- ["<cr>"] = "RET",
    -- ["<tab>"] = "TAB",
  },
  icons = {
    separator = "➜", -- symbol used between a key and it's label
    breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
    group = "+",      -- symbol prepended to a group
  },
  popup_mappings = {
    scroll_down = '<c-d>', -- binding to scroll down inside the popup
    scroll_up = '<c-u>',   -- binding to scroll up inside the popup
  },
  window = {
    border = "none",          -- none, single, double, shadow
    position = "bottom",      -- bottom, top
    margin = { 1, 0, 1, 0 },  -- extra window margin [top, right, bottom, left]
    padding = { 2, 2, 2, 2 }, -- extra window padding [top, right, bottom, left]
    winblend = 0
  },
  layout = {
    height = { min = 4, max = 25 },                                             -- min and max height of the columns
    width = { min = 20, max = 50 },                                             -- min and max width of the columns
    spacing = 3,                                                                -- spacing between columns
    align = "left",                                                             -- align columns left, center or right
  },
  ignore_missing = false,                                                       -- enable this to hide mappings for which you didn't specify a label
  hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "call", "lua", "^:", "^ " }, -- hide mapping boilerplate
  show_help = true,                                                             -- show help message on the command line when the popup is visible
  show_keys = true,                                                             -- show the currently pressed key and its label as a message in the command line
  triggers = "auto",                                                            -- automatically setup triggers
  -- triggers = {"<leader>"} -- or specify a list manually
  triggers_blacklist = {
    -- list of mode / prefixes that should never be hooked by WhichKey
    -- this is mostly relevant for key maps that start with a native binding
    -- most people should not need to change this
    i = { "j", "k" },
    v = { "j", "k" },
  },
  -- disable the WhichKey popup for certain buf types and file types.
  -- Disabled by deafult for Telescope
  disable = {
    buftypes = {},
    filetypes = { "TelescopePrompt" },
  },
}

wk.register(mappings, options)

wk.register({
  x = { '"_x', "Delete character (dont copy)" },
  X = { '"_X', "Delete character (dont copy)" },
  c = { '"_c', "change (dont copy)" },
  C = { '"_C', "change till end of line (dont copy)" },
  cc = { '"_cc', "change line (dont copy)" },
  Y = { '^y$', "Yank line (without whitespace" },
  -- ["C-j"] = { '<CMD>execute "move+<CR>"', "Move line down" },
  -- ["C-k"] = { 'execute "move-<cr>"', "Move line up" },
  -- ["C-s"] = { 'execute "update<cr>"', "Save file" },
  ["<C-h>"] = ':echo "ping"<cr>',
  --0["c-s"] = { "<cmd>update<cr>", "save file" },
  -- ["Q"] = { '@q', "Replay register `q`" },
}, { noremap = true, mode = 'n' })

wk.register({
  p = { 'pgvy', "Paste (without copying replacement)" },
  -- ["C-j"] = { "<silent> <cmd>move'>+<cr>gv", "Move line down" }
}, { noremap = true, mode = 'x' })

vim.cmd [[ nnoremap <silent> <C-s> :update<CR> ]]

-- ----------------------
-- GPT file AMA
-- ----------------------

vim.cmd([[
  command! -nargs=0 SgptDiscussionN let outputFile = tempname() | let inputFile = tempname() | execute "%w " . inputFile | silent execute "vsp | terminal printf 'First response should be: Ready!. Do not say anything else until i respond.\\n'  | cat " . inputFile . " | sed ':a;N;$!ba;s/\\n/\\\\n/g' | sgpt --role describe-code-ama --chat '" . substitute(expand('%:p'), '/', '_', 'g') ."' | tee /dev/tty > /dev/null; sgpt --role describe-code-ama --repl '" . substitute(expand('%:p'), '/', '_', 'g') ."'; cat '" . expand('~') . "/.cache/shell_gpt/chat_cache/" . substitute(expand('%:p'), '/', '_', 'g') . "' | jq -r '.[] | \"\\(.role): \\(.content)\\n\"' > '".outputFile."'; nvr -cc 'startinsert!' '".outputFile."' +'set ft=markdown'"
]])

wk.register({
  ['<leader>ad'] = { ':SgptDiscussionN<CR>', "GPT AMA: File" },
}, { noremap = true, mode = 'n' })

vim.cmd([[
  command! -range -nargs=0 SgptDiscussionV execute "normal! `<v`>y" | let outputFile = tempname() | let inputFile = tempname() | call writefile(split(@", "\n"), inputFile) | silent execute "vsp | terminal printf 'First response should be: Ready!. Do not say anything else until i respond.\\n' | cat " . inputFile . " | sed ':a;N;$!ba;s/\\n/\\\\n/g' | sgpt --role describe-code-ama --chat '" . substitute(outputFile, '/', '_', 'g') ."' | tee /dev/tty > /dev/null; sgpt --role describe-code-ama --repl '" . substitute(outputFile, '/', '_', 'g') ."'; cat '" . expand('~') . "/.cache/shell_gpt/chat_cache/" . substitute(outputFile, '/', '_', 'g') . "' | jq -r '.[] | \"\\(.role): \\(.content)\\n\"' > '".outputFile."'; nvr -cc 'startinsert!' '".outputFile."' +'set ft=markdown'"
]])

wk.register({
  ['<leader>ad'] = { ':SgptDiscussionV<CR>', "GPT AMA: Snippet", mode = 'x' }
}, { noremap = true })

-- ----------------------
-- GPT Explain
-- ----------------------

vim.cmd([[
  command! -nargs=0 SgptExplainN let outputFile = tempname() | let inputFile = tempname() | execute "%w " . inputFile | silent execute "vsp | terminal cat " . inputFile . " | sed ':a;N;$!ba;s/\\n/\\\\n/g' | sgpt --role describe-code --chat '" . substitute(expand('%:p'), '/', '_', 'g') ."' | tee /dev/tty > /dev/null; sgpt --role describe-code --repl '" . substitute(expand('%:p'), '/', '_', 'g') ."'; cat '" . expand('~') . "/.cache/shell_gpt/chat_cache/" . substitute(expand('%:p'), '/', '_', 'g') . "' | jq -r '.[] | \"\\(.role): \\(.content)\\n\"' > '".outputFile."'; nvr '".outputFile."' +'set ft=markdown' +'startinsert'"
]])

wk.register({
  ['<leader>ax'] = { ':SgptExplainN<CR>', "Describe: File", mode = 'n' },
}, { noremap = true })

vim.cmd([[
  command! -range -nargs=1 SgptCodeV execute "normal! `<v`>y" | let outputFile = tempname() | let inputFile = tempname() | call writefile(split(@", "\n"), inputFile) | silent execute "vsp | terminal cat " . inputFile . " | sgpt --code '".<q-args>."' | tee /dev/tty > " . outputFile . " && nvr " . outputFile . " +'set ft=" . &filetype . "' +'edit'"
]])

wk.register({
  ['<leader>ax'] = { ':SgptExplainV<CR>', "Describe: Selection", mode = 'x' },
}, { noremap = true })

-- ----------------------
-- GPT Neovim
-- ----------------------

vim.cmd([[
  command! -range -nargs=1 SgptNeovim :FloatermNew --height=0.2 --width=0.4 --wintype=float --name=floaterm1 --position=center --title=Neovim\ GPT --autoclose=1 sgpt --role vim '<q-args>' && tput civis; stty -echo; while IFS= read -r -n1 key; do if [ "$key" = "q" ] || [ "$key" = "$(printf '\033')" ]; then break; fi; done; stty echo; tput cnorm
]])

wk.register({
  ['<leader>av'] = { ':SgptNeovim<space>', "Neovim GPT", mode = 'n' },
}, { noremap = true })

wk.register({
  ['<leader>av'] = { ':SgptNeovim<space>', "Neovim GPT", mode = 'x' },
}, { noremap = true })

-- ----------------------
-- GPT Chat (no context)
-- ----------------------

vim.cmd([[
  command! -nargs=0 Sgpt silent execute "vsp | terminal sgpt --model gpt-4 --temperature 1 --repl ".tempname()
]])

-- ----------------------
-- GPT Git Staging
-- ----------------------

vim.cmd([[
  command! -nargs=0 SgptStaging let outputFile = tempname() | silent execute "vsp | terminal git diff --staged | tr -s '[:space:]' '\\n' | head -n 3500 | tr -s '[:space:]' ' ' | sgpt --model gpt-4 --temperature 1 'Look at the staged changes. Find and list all potential issues. Do not be afraid to create a long list. When an issue is found, list the filename, full description of the issue, line range, a new line and no more than a 3 line markdown code snippet. Say -All good- if you are unable to find any issues.' | tee /dev/tty > " . outputFile . " && nvr " . outputFile . " +'set ft=markdown' +'edit'"
]])

wk.register({
  ['<leader>ags'] = { ':SgptStaging<cr>', "analyze staged files", mode = 'n' },
}, { noremap = true })

-- ----------------------
-- GPT Code (Prompt)
-- ----------------------

vim.cmd([[
  command! -nargs=1 SgptCodeN let outputFile = tempname() | let inputFile = tempname() | execute "%w " . inputFile | silent execute "vsp | terminal cat " . inputFile . " | sgpt --code '".<q-args>."' | tee /dev/tty > " . outputFile . " && nvr " . outputFile . " +'set ft=markdown'"
]])

wk.register({
  ['<leader>ac'] = { ':SgptCodeN<space>', "Coder: Prompt", mode = 'n' },
}, { noremap = true })

vim.cmd([[
  command! -range -nargs=1 SgptCodeV execute "normal! `<v`>y" | let outputFile = tempname() | let inputFile = tempname() | call writefile(split(@", "\n"), inputFile) | silent execute "vsp | terminal cat " . inputFile . " | sgpt --code '".<q-args>."' | tee /dev/tty > " . outputFile . " && nvr " . outputFile . " +'set ft=" . &filetype . "' +'edit'"
]])

wk.register({
  ['<leader>ac'] = { ':SgptCodeV<space>', "Coder: Prompt", mode = 'x' },
}, { noremap = true })

-- ----------------------
-- GPT Code variations
-- ----------------------


wk.register({
  ['<leader>a'] = {
    name = 'GPT',
    a = { ':Sgpt<CR>', "Chat (no context)" },
    r = { ':SgptCodeN Generate a README.md<CR>', "Generate README.md" },
    p = {
      ':SgptCodeN You are a Principal software architect. Please analyze the code and create an actionable markdown task list of improvements, security risks, bugs. Each item should be coupled with a detailed description.<CR>',
      "Actionable Review" },
    m = {
      name = 'Mermaid',
      s = { ':SgptCodeN Write this code as a mermaid sequence diagram<CR>', "Mermaid Sequence Diagram" },
      m = { ':SgptCodeN Write this code as a mermaid state diagram<CR>', "Mermaid State Diagram" },
    },
    t = {
      name = 'Tests',
      u = {
        name = 'Unit Tests',
        a = { ':SgptCodeN Write all unit tests for this code<CR>', "Write All Unit Tests" },
        o = {
          ':SgptCodeN Write all necessary unit test stubs for this code. Include detailed comments explaining how to approach the test. All stub functions should use `.skip`<CR>',
          "Write Unit Test Stubs" },
      },
      i = {
        name = 'Integration Tests',
        a = { ':SgptCodeN Write all integration tests for this code<CR>', "Write All Integration Tests" },
        o = {
          ':SgptCodeN Write all necessary integration test stubs for this code. Include detailed comments explaining how to approach the test. All stub functions should use `.skip`<CR>',
          "Write All Integration Test Stubs" },
      },
    },
  },
}, { noremap = true, mode = 'n' })

wk.register({
  ['<leader>a'] = {
    name = 'GPT',
    r = { ':SgptCodeV Generate a README.md<CR>', "Generate README.md" },
    p = {
      ':SgptCodeV You are a Principal software architect. Please analyze the code and create an actionable markdown task list of improvements, security risks, bugs. Each item should be coupled with a detailed description.<CR>',
      "Actionable Review" },
    m = {
      name = 'Mermaid',
      s = { ':SgptCodeV Write this code as a mermaid sequence diagram<CR>', "Mermaid Sequence Diagram" },
      m = { ':SgptCodeV Write this code as a mermaid state diagram<CR>', "Mermaid State Diagram" },
    },
    t = {
      name = 'Tests',
      u = {
        name = 'Unit Tests',
        a = { ':SgptCodeV Write all unit tests for this code<CR>', "Write All Unit Tests" },
        o = { ':SgptCodeV Write all necessary unit test stubs for this code. Include comments explaining each stub.<CR>',
          "Write Unit Test Stubs" },
      },
      i = {
        name = 'Integration Tests',
        a = { ':SgptCodeV Write all integration tests for this code<CR>', "Write All Integration Tests" },
        o = {
          ':SgptCodeV Write all necessary integration test stubs for this code. Include comments explaining each stub.<CR>',
          "Write All Integration Test Stubs" },
      },
    },
  },
}, { noremap = true, mode = 'x' })
