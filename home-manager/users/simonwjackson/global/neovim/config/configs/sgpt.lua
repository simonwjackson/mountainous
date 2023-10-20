require('which-key').register({
  ['<leader>a'] = {
    name = 'GPT',
    x = { ':SgptExplainN<CR>', "Describe: File", mode = 'n' },
    v = { ':SgptNeovim<space>', "Neovim GPT", mode = 'n' },
    a = { ':Sgpt<CR>', "Chat (no context)" },
    c = { ':SgptCodeN<space>', "Coder: Prompt", mode = 'n' },
    d = { ':SgptDiscussionN<CR>', "GPT AMA: File" },
    gs = { ':SgptStaging<cr>', "analyze staged files", mode = 'n' },
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

require('which-key').register({
  ['<leader>a'] = {
    name = 'GPT',
    c = { ':SgptCodeV<space>', "Coder: Prompt", mode = 'x' },
    d = { ':SgptDiscussionV<CR>', "GPT AMA: Snippet", mode = 'x' },
    m = {
      name = 'Mermaid',
      s = { ':SgptCodeV Write this code as a mermaid sequence diagram<CR>', "Mermaid Sequence Diagram" },
      m = { ':SgptCodeV Write this code as a mermaid state diagram<CR>', "Mermaid State Diagram" },
    },
    p = {
      ':SgptCodeV You are a Principal software architect. Please analyze the code and create an actionable markdown task list of improvements, security risks, bugs. Each item should be coupled with a detailed description.<CR>',
      "Actionable Review" },
    r = { ':SgptCodeV Generate a README.md<CR>', "Generate README.md" },
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
    v = { ':SgptNeovim<space>', "Neovim GPT", mode = 'x' },
    x = { ':SgptExplainV<CR>', "Describe: Selection", mode = 'x' },
  },
}, { noremap = true, mode = 'x' })

-- ----------------------
-- GPT file AMA
-- ----------------------

vim.cmd([[
  command! -nargs=0 SgptDiscussionN let outputFile = tempname() | let inputFile = tempname() | execute "%w " . inputFile | silent execute "vsp | terminal printf 'First response should be: Ready!. Do not say anything else until i respond.\\n'  | cat " . inputFile . " | sed ':a;N;$!ba;s/\\n/\\\\n/g' | sgpt --role describe-code-ama --chat '" . substitute(expand('%:p'), '/', '_', 'g') ."' | tee /dev/tty > /dev/null; sgpt --role describe-code-ama --repl '" . substitute(expand('%:p'), '/', '_', 'g') ."'; cat '" . expand('~') . "/.cache/shell_gpt/chat_cache/" . substitute(expand('%:p'), '/', '_', 'g') . "' | jq -r '.[] | \"\\(.role): \\(.content)\\n\"' > '".outputFile."'; nvr -cc 'startinsert!' '".outputFile."' +'set ft=markdown'"
]])


vim.cmd([[
  command! -range -nargs=0 SgptDiscussionV execute "normal! `<v`>y" | let outputFile = tempname() | let inputFile = tempname() | call writefile(split(@", "\n"), inputFile) | silent execute "vsp | terminal printf 'First response should be: Ready!. Do not say anything else until i respond.\\n' | cat " . inputFile . " | sed ':a;N;$!ba;s/\\n/\\\\n/g' | sgpt --role describe-code-ama --chat '" . substitute(outputFile, '/', '_', 'g') ."' | tee /dev/tty > /dev/null; sgpt --role describe-code-ama --repl '" . substitute(outputFile, '/', '_', 'g') ."'; cat '" . expand('~') . "/.cache/shell_gpt/chat_cache/" . substitute(outputFile, '/', '_', 'g') . "' | jq -r '.[] | \"\\(.role): \\(.content)\\n\"' > '".outputFile."'; nvr -cc 'startinsert!' '".outputFile."' +'set ft=markdown'"
]])


-- ----------------------
-- GPT Explain
-- ----------------------

vim.cmd([[
  command! -nargs=0 SgptExplainN let outputFile = tempname() | let inputFile = tempname() | execute "%w " . inputFile | silent execute "vsp | terminal cat " . inputFile . " | sed ':a;N;$!ba;s/\\n/\\\\n/g' | sgpt --role describe-code --chat '" . substitute(expand('%:p'), '/', '_', 'g') ."' | tee /dev/tty > /dev/null; sgpt --role describe-code --repl '" . substitute(expand('%:p'), '/', '_', 'g') ."'; cat '" . expand('~') . "/.cache/shell_gpt/chat_cache/" . substitute(expand('%:p'), '/', '_', 'g') . "' | jq -r '.[] | \"\\(.role): \\(.content)\\n\"' > '".outputFile."'; nvr '".outputFile."' +'set ft=markdown' +'startinsert'"
]])


vim.cmd([[
  command! -range -nargs=1 SgptCodeV execute "normal! `<v`>y" | let outputFile = tempname() | let inputFile = tempname() | call writefile(split(@", "\n"), inputFile) | silent execute "vsp | terminal cat " . inputFile . " | sgpt --code '".<q-args>."' | tee /dev/tty > " . outputFile . " && nvr " . outputFile . " +'set ft=" . &filetype . "' +'edit'"
]])


-- ----------------------
-- GPT Neovim
-- ----------------------

vim.cmd([[
  command! -range -nargs=1 SgptNeovim :FloatermNew --height=0.2 --width=0.4 --wintype=float --name=floaterm1 --position=center --title=Neovim\ GPT --autoclose=1 sgpt --role vim '<q-args>' && tput civis; stty -echo; while IFS= read -r -n1 key; do if [ "$key" = "q" ] || [ "$key" = "$(printf '\033')" ]; then break; fi; done; stty echo; tput cnorm
]])


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


-- ----------------------
-- GPT Code (Prompt)
-- ----------------------

vim.cmd([[
  command! -nargs=1 SgptCodeN let outputFile = tempname() | let inputFile = tempname() | execute "%w " . inputFile | silent execute "vsp | terminal cat " . inputFile . " | sgpt --code '".<q-args>."' | tee /dev/tty > " . outputFile . " && nvr " . outputFile . " +'set ft=markdown'"
]])


vim.cmd([[
  command! -range -nargs=1 SgptCodeV execute "normal! `<v`>y" | let outputFile = tempname() | let inputFile = tempname() | call writefile(split(@", "\n"), inputFile) | silent execute "vsp | terminal cat " . inputFile . " | sgpt --code '".<q-args>."' | tee /dev/tty > " . outputFile . " && nvr " . outputFile . " +'set ft=" . &filetype . "' +'edit'"
]])
