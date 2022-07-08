# TODO: Remove the need to grep for the window title
function activate () {
  echo "${line}" \
      | awk '{print $1}' \
      | xargs bt activate \
  && sleep .01 && xdotool windowactivate "$(xdotool search --onlyvisible --name firefox | wmctrl -l | grep "${title_pattern}" | head -n 1 | awk '{print $1}')";
}


url="${1}"
shift 1

while [ $# -gt 0 ]; do
   case "${1}" in
     -u|--url-pattern)
       url_pattern="${2}"
       shift 2;;
     -p|--title-pattern)
       title_pattern="${2}"
       shift 2;;
     *)
       break;;
    esac
done

# see: https://stackoverflow.com/a/49627999
safe_grep() { grep "$@" || test $? = 1; }

line="$(bt list | safe_grep "${url_pattern:-url}" | head -n 1)"

if [[ -n "${line}" ]]; then
    activate
else
    xdg-open "${url}"
fi
