bindkey -s '^e' 'nvim^M'
bindkey -s '^g' 'lazygit^M'

# bindkey -s '\eOP'    '<COMMAND>^M'    # F1
# bindkey -s '\eOQ'    '<COMMAND>^M'    # F2
# bindkey -s '\eOR'    '<COMMAND>^M'    # F3
# bindkey -s '\eOS'    '<COMMAND>^M'    # F4
# bindkey -s '\e[15~'  '<COMMAND>^M'    # F5
bindkey -s '\e[17~'  'git-here^M'     # F6
bindkey -s '\e[18~'  'nvim $(fzf)^M'  # F7
# bindkey -s '\e[19~'  '<COMMAND>^M'    # F8
# bindkey -s '\e[20~'  '<COMMAND>^M'    # F9
# bindkey -s '\e[21~'  '<COMMAND>^M'    # F10
# bindkey -s '\e[23~'  '<COMMAND>^M'    # F11
# bindkey -s '\e[24~ ' '<COMMAND>^M'    # F12

bindkey -M vicmd v edit-command-line
