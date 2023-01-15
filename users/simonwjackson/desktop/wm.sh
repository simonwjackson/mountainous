command=$1
wm=${2:-$(wmctrl -m | head -n 1 | awk -F ':' '{print $2}' | tr -d "[:blank:]")}


case $command in
  monocle )
    case $wm in
      awesome)
        # INFO: Better implementation:
        # https://www.reddit.com/r/awesomewm/comments/87coru/wouldnt_it_be_wise_to_hide_underlying_windows_in/
        awesome-client '
        local awful = require "awful"
        if not string.match(awful.layout.getname(), "max") then
          prev_layout = awful.layout.get()
          awful.layout.set(awful.layout.suit.max)

        else
          awful.layout.set(prev_layout)
        end
        '
        ;;

      bspwm )
        bspc desktop -l next
        ;;
    esac
    ;;
  grow )
    case $wm in
      awesome)
        awesome-client '
        require("awful").tag.incmwfact(0.02)
        '
        ;;
    esac
    ;;

  shrink )
    case $wm in
      awesome)
        awesome-client '
        require("awful").tag.incmwfact(-0.02)
        '
        ;;
    esac
    ;;
  * )
    echo "Unknown command: $command"
    ;;
esac
