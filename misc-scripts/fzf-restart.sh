file=/tmp/temp_file
trap "exit" INT

while true; do
  fzf --bind 'ctrl-c:abort,esc:abort' <"$file" >/tmp/fzf_output &
  FZF_PID=$!

  inotifywait -e modify "$file" >/dev/null 2>&1 &
  INOTIFY_PID=$!

  wait -n
  EXIT_CODE=$?

  # ctrl-c or esc
  if [ $EXIT_CODE -eq 130 ] || [ $EXIT_CODE -eq 1 ]; then
    kill -9 "$INOTIFY_PID"
    break
  elif [ $EXIT_CODE -eq 0 ] && [ -d /proc/$INOTIFY_PID ]; then
    break
    cat /tmp/fzf_output
  else
    kill -9 "$FZF_PID"
  fi
done
