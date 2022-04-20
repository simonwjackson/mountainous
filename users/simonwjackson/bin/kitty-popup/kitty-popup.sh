# TODO: Find a way to decouple bspwm from this script
[[ $(pgrep -u $UID bspwm) ]] && {
  bspc \
    rule -a 'floating-term' \
    state=floating \
    follow=on \
    focus=on \
    rectangle="2000x1500+0+0" \
    center=true
}

for win in $(xwininfo -root -children | awk 'NR > 6 {print $1}'); do
  picom-trans --window="${win}" --opacity=15 &
done

# --override window_padding_width=10 \
# --override background='#101010' \

kitty \
  --class floating-term \
  "${SHELL}" -c "$*" \
&& picom-trans --reset
