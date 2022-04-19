# TODO: Find a way to decouple bspwm from this script
[[ $(pgrep -u $UID bspwm) ]] && {
  bspc \
    rule -a 'floating-term' \
    state=floating \
    follow=on \
    focus=on \
    rectangle="${KITTY_POPUP_WIDTH:-1000}x${KITTY_POPUP_HEIGHT:-1000}+0+0" \
    center=true
}

kitty \
  --override window_padding_width=10 \
  --override background='#101010' \
  --class floating-term \
  "${SHELL}" -c "$*"
