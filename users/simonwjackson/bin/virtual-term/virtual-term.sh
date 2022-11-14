export DISPLAY=:0

case $1 in
  start)
    kitty \
    --single-instance \
    --detach \
    --title VIRTUAL_TERM_1 \
    --name VIRTUAL_TERM_1 \
    --class VIRTUAL_TERM_1 \
    --override 'font_size=0' \
    -- tmux \
      -L VIRTUAL_TERM_1 \
      -f "${HOME}/.config/tmux/share.tmux.conf" \
      new-session \
      -A \
      -s SERVER \
      'export TMUX=; exec tmux new-session -A -s INNER'

    #sleep .5
    #id=$(xdotool search --classname VIRTUAL_TERM_1 | head -n 1)
    #bspc node "$id" --flag hidden=on
  ;;

  stop)
    id=$(xdotool search --classname VIRTUAL_TERM_1 | head -n 1)
    xkill -id "${id}"
  ;;

  deactivate)
    id=$(xdotool search --classname VIRTUAL_TERM_1 | head -n 1)
    #bspc node "$id" --flag hidden=on
  ;;

  activate)
    id=$(xdotool search --classname VIRTUAL_TERM_1 | head -n 1)
    #bspc node "$id" --flag hidden=off
    bspc node "$id" --to-desktop focused --follow
    bspc node "$id" --focus
  ;;
esac;
