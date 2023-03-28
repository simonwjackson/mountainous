read -r input
type="${input:0:1}"
line="${input:2}"
scrubbed="${line//&amp;/&}"

MY_PATH="$(dirname -- "${BASH_SOURCE[0]}")"

case $type in
  裡)
    echo "${scrubbed}" | "${MY_PATH}/tabs_set.py"
    ;;
   )
    echo "${scrubbed}" | xargs wmctrl -a
    ;;
  󰋚 )
    echo "${scrubbed}" | sed -e 's/.*| //' | sed -e 's/<\/span>//' | xargs "${BROWSER}"
    ;;
  * )
    echo "Giving up"
    ;;
esac


