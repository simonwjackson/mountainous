# TODO: Remove kitty from pipe to avoid unessicary term popup
(cd ~/documents/notes/meetings ; rg --vimgrep --no-heading --smart-case .) \
  | rofi -dmenu -i \
  | awk -F ':' '{print $1}' \
  | sed 's/\.md//g' \
  | xargs -I @ "${TERMINAL}" -- nvim  +'VimwikiIndex' +"VimwikiGoto meetings/@" +'Goyo' -c 'nnoremap <M-x> :xa!<CR>'
