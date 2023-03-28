for f in /home/simonwjackson/*.desktop; do
  grep -E '(Name|Comment)' "${f}" \
    | sed 's/Name=//' \
    | sed 's/Comment=\(.*\)/<span foreground="#8a8a8a" size="small">\1<\/span>/' \
    | xargs -d '\n' \
    | xargs -d '\n' -I % echo "${f}:%"
    done \
      | rofi \
      -dpi 300 \
      -dmenu \
      -i \
      -display-column-separator ':' \
      -display-columns 2 \
      -markup-rows \
      | awk -F ':' '{print $1}' \
      | xargs gio launch
