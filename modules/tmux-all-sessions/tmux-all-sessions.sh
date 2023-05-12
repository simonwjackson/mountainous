function replace_delimiter_with_spaces () {
  local delimiter="$1"
  local num_spaces="$2"
  local spaces=$(printf '\u2007%.0s' $(seq 1 "$num_spaces"))

  sed -u "s/${delimiter}/${spaces}/g"
}

function replace_spaces_with_delimiter() {
  local delimiter="$1"
  local num_spaces="$2"
  local spaces=$(printf '\u2007%.0s' $(seq 1 "$num_spaces"))

  sed -u "s/${spaces}/${delimiter}/g"
}

display_icon() {
  icon_inactive=""
  icon_active=""

  if [ "$1" ];
  then
    echo "$icon_active"
  else
    echo "$icon_inactive"
  fi
}

export -f display_icon

to_csv() {
  dir="$1"

  session_name="$(basename "$(dirname "$dir")")/$(basename "$dir")"
  tmux_status=$( \
    tmux has-session -t "$session_name" > /dev/null 2>&1 \
    && display_icon "$?"
  )

  printf "%s,code,%s,%s\n" "$dir" "$tmux_status" "$session_name"
}

export -f to_csv

selection=$(fd --type directory --hidden '^.bare$|^.git$' --search-path ~/code \
  | xargs -I {} dirname {} \
  | xargs -I {} bash -c 'to_csv "{}"' \
  | replace_delimiter_with_spaces ',' 2 \
  | fzf \
  --bind 'ctrl-c:abort' \
  --delimiter=$'\u2007' \
  --with-nth=4.. \
  | replace_spaces_with_delimiter ',' 2 \
)

[ -z "$selection" ] && exit 1

path=$(cut -d',' -f1 <<< "$selection");
type=$(cut -d',' -f2 <<< "$selection");
name=$(cut -d',' -f4 <<< "$selection");

if [ "$type" = "code" ]; then
  command="tmux split-window -h -p 20 && tmux split-window -v -t 0 && tmux send-keys -t 1 \"nvim; exec ${SHELL:-/bin/sh}\" Enter"
fi

if ! tmux has-session -t "$name" 2>/dev/null;
then
  creating_session=true
fi

tmux new-session -d -c "$path" -s "$name" "$command" > /dev/null 2>&1

if [ "$creating_session" = true ];
then
  # msg="$(Creating session: $name | boxes -d unicornthink)"

  # printf "\033[0;0H\033[2J";
  # cols=$(tput cols);
  # lines=$(tput lines);
  # printf "\033[$((lines/2));$(((cols-${#msg})/2))H%s" "$msg"

fi

if [[ -z "$TMUX" ]]; then
  tmux attach-session -t "$name"
else
  tmux switch-client -t "$name"
fi
