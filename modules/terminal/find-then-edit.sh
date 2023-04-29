#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash fzf bat

fzf \
  --preview='bat --color=always {}' \
  --preview-window "$(if [ "$(tput cols)" -lt 120 ]; then echo 'down:70%'; else echo 'right:70%'; fi)" \
  --bind 'ctrl-c:abort' \
  --ansi \
  --layout=reverse \
  --print-query \
  | tail -n +2 \
  | awk -F': *' '{print $1}' \
  | awk '{$1=$1};1' \
  | xargs -r $EDITOR
