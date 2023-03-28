MY_PATH="$(dirname -- "${BASH_SOURCE[0]}")"

wmctrl -l | cut -d ' ' -f 5- | sed 's/ — Mozilla Firefox//' | xargs -I % -d'\n' echo  "%" &
"${MY_PATH}/tabs_get.py" | xargs -I % -d'\n' echo 裡 "%" &
"${MY_PATH}/ff-hist.sh" | awk -v FS='   *' '{print $3 " <span foreground=\"#8a8a8a\" size=\"small\">| " $4 "</span>"}' | xargs -I % -d'\n' echo 󰋚 "%" &
