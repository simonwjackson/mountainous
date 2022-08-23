#!/bin/bash

date=$(date '+%Y-%m-%dT%H:%M:%S')
slop=$(slop -f "%x %y %w %h %g %i") || exit 1
read -r X Y W H G ID <<< $slop

ffmpeg -f x11grab -s "$W"x"$H" -i :0.0+$X,$Y "~/videos/${date}.webm"
