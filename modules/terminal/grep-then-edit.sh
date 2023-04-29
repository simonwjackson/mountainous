#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash fzf bat ripgrep

export INITIAL_QUERY=""
export RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
export FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'"

SELECTED_LINE=$("fzf" \
  --preview='echo {} | awk -F: '\''{print $1 " " $2}'\'' | xargs -I % sh -c '\''bat --color=always --highlight-line $(echo % | cut -d" " -f2) "$(echo % | cut -d" " -f1)"'\''' \
  --preview-window "$(if [ "$(tput cols)" -lt 120 ]; then echo 'down:70%'; else echo 'right:70%'; fi)" \
  --bind "change:reload:$RG_PREFIX {q} || true" \
  --bind 'ctrl-c:abort' \
  --ansi \
  --phony \
  --query "$INITIAL_QUERY" \
  --layout=reverse \
  --print-query \
  | tail -n +2
)

if [ -n "$SELECTED_LINE" ]; then
  FILE_PATH=$(echo "$SELECTED_LINE" | awk -F': *' '{print $1}' | awk '{$1=$1};1')
  LINE_NUMBER=$(echo "$SELECTED_LINE" | awk -F': *' '{print $2}')

  if [ "$EDITOR" = "nvim" ] || [ "$EDITOR" = "vim" ]; then
    $EDITOR "+$LINE_NUMBER" "$(echo "$FILE_PATH" | awk '{$1=$1};1')"
  else
    $EDITOR "$FILE_PATH";
  fi
fi
