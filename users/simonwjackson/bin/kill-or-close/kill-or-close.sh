#!/bin/sh

if [[ $(xdotool getwindowfocus getwindowname) =~ " — Mozilla Firefox" ]]; then
  sleep .1 && xdotool keyup "w" key --clearmodifiers "ctrl+w"
elif [[ $(xdotool getwindowfocus getwindowname) =~ "qutebrowser" ]]; then
  sleep .01 && xdotool key --clearmodifiers esc
  sleep .01 && xdotool key --clearmodifiers esc
  sleep .01 && xdotool keyup "d" key --clearmodifiers d
elif [[ $(xdotool getwindowfocus getwindowname) =~ "tmux" ]]; then
  sleep .01 && xdotool keyup "x" key --clearmodifiers "alt+x"
else
  bspc node -c
fi
