servers="unzen\nfiji\nkita\nyari"
selection=$(
  echo -e "$servers" |
    fzf \
      --delimiter='\n' \
      --bind 'ctrl-c:abort'
)

[ -z "$selection" ] && exit 1

tmux new-session -d -s "$selection" mosh "$selection" -- sh -c 'tmux -f ~/.config/tmux/tmux.host.conf attach-session -t terminals || tmux -f ~/.config/tmux/tmux.host.conf new-session -s terminals nvim -c "terminal" -c "startinsert"' >/dev/null 2>&1

if [[ -z "$TMUX" ]]; then
  tmux attach-session -t "$selection"
else
  tmux switch-client -t "$selection"
fi
