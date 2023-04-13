unique_class="asdf"

while true; do
  app_win_ids=$(xprop -root _NET_CLIENT_LIST_STACKING | grep -oP "#\K[0-9a-fx]+")
  app_pid=""

  for win_id in $app_win_ids; do
    win_class=$(xprop -id $win_id WM_CLASS | grep -oP "STRING \"\K[^\",]+")
    if [[ $win_class == $unique_class ]]; then
      app_pid=$win_id
      break
    fi
  done

  if [[ -n "${app_pid}" ]]; then
    overlay_id=$(xwininfo -root -children | grep -oP "0x[0-9a-f]+")
    if [[ -z "${overlay_id}" ]]; then
      xcompmgr -c -C -t-0.1 -l0.1 -r4.2 -o.2 &
      sleep 0.1
      xdotool windowunmap --sync "${app_pid}"
      xdotool windowmap --sync "${app_pid}"
      transset-df -i "${app_pid}" --inc 1
    fi
  else
    if [[ -n "${overlay_id}" ]]; then
      killall xcompmgr
      xdotool windowunmap --sync "${overlay_id}"
      xdotool windowmap --sync "${overlay_id}"
    fi
  fi

  sleep 1
done
