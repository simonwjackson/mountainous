servers="unzen\nfiji\nkita\nyari"
server_selection=$(
  echo -e "$servers" |
    fzf \
      --delimiter='\n' \
      --bind 'ctrl-c:abort'
)

[ -z "$server_selection" ] && exit 1

tmux -L HOST new-session -d -s "$server_selection" mosh "$server_selection" -- sh -c 'tmux -L WORKSPACE -f ~/.config/tmux/tmux.workspace.conf attach-session -t terminals || tmux -L WORKSPACE -f ~/.config/tmux/tmux.workspace.conf new-session -s terminals nvim -c "terminal" -c "startinsert"' >/dev/null 2>&1

if [[ -z "$TMUX" ]]; then
  tmux -L HOST attach-session -t "$server_selection"
else
  tmux -L HOST switch-client -t "$server_selection"
fi
