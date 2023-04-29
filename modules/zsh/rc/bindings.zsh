function nvim-worktree () {
  [[ -f ./packed-refs ]] && git worktree list | awk '{print $3}' | awk 'NF > 0' && nvim +"lua require('telescope').extensions.git_worktree.git_worktrees()" $* || nvim $*
}

bindkey -s '^e' 'nvim-worktree^M'
bindkey -s '^g' 'lazygit^M'

# bindkey -s '\eOP'    '<COMMAND>^M'    # F1
bindkey -s '\eOQ'    'grep-then-edit^M'    # F2
# bindkey -s '\eOR'    '<COMMAND>^M'    # F3
# bindkey -s '\eOS'    '<COMMAND>^M'    # F4
# bindkey -s '\e[15~'  '<COMMAND>^M'    # F5
bindkey -s '\e[17~'  'git-here^M'     # F6
bindkey -s '\e[18~'  'find-then-edit^M'  # F7
# bindkey -s '\e[19~'  '<COMMAND>^M'    # F8
# bindkey -s '\e[20~'  '<COMMAND>^M'    # F9
# bindkey -s '\e[21~'  '<COMMAND>^M'    # F10
# bindkey -s '\e[23~'  '<COMMAND>^M'    # F11
# bindkey -s '\e[24~ ' '<COMMAND>^M'    # F12

bindkey -M vicmd v edit-command-line
