current_resolution=$(xrandr | rg '\+$' | awk '{print $1}')
popup_resolution=$(echo "${current_resolution}" | sed 's/x/\n/' | xargs -I X echo "X * .8" | bc | cut -d. -f1 | tr '\n' 'x' | sed 's/x$//')

# TODO: Find a way to decouple bspwm from this script
[[ $(pgrep -u $UID bspwm) ]] && {
  bspc \
    rule -a 'floating-term' \
    state=floating \
    follow=on \
    focus=on \
    rectangle="${popup_resolution}+0+0" \
    center=true
}

bspwm_layout=$(bspc query -T -d | jq -r .layout)
all_windows=$(bspc query -N)

if [ "${bspwm_layout}" == "monocle" ]; then
  active_window=$(bspc query -N -n);
  hidden_windows=$( { echo "${active_window}"; echo "${all_windows}"; } | sort | uniq -u);

  for win in $hidden_windows; do
    picom-trans --window="${win}" --opacity=0 || true
  done

  # HACK: Allows for better transitions when in monocle mode
  sleep .06

  picom-trans --window="${active_window}" --opacity=15 &
else
  for win in $all_windows; do
    picom-trans --window="${win}" --opacity=15 &
  done
fi

# for win in $(xwininfo -root -children | awk 'NR > 6 {print $1}'); do
#   picom-trans --window="${win}" --opacity=15 &
# done

# --override window_padding_width=10 \
# --override background='#101010' \

kitty \
  --class floating-term \
  "${SHELL}" -c "$*" && picom-trans --reset;
