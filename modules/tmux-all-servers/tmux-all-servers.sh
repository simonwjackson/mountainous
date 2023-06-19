servers="unzen\nfiji\nkita\nyari"
selection=$(
  echo -e "$servers" |
    fzf \
      --delimiter='\n' \
      --bind 'ctrl-c:abort'
)

[ -z "$selection" ] && exit 1

tmux -L HOST new-session -d -s "$selection" mosh "$selection" -- sh -c 'tmux -L WORKSPACE -f ~/.config/tmux/tmux.workspace.conf attach-session -t terminals || tmux -L WORKSPACE -f ~/.config/tmux/tmux.workspace.conf new-session -s terminals nvim -c "terminal" -c "startinsert"' >/dev/null 2>&1

if [[ -z "$TMUX" ]]; then
  tmux attach-session -t "$selection"
else
  tmux switch-client -t "$selection"
fi
