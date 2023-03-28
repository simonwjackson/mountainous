MY_PATH="$(dirname -- "${BASH_SOURCE[0]}")"

"${MY_PATH}/cmd_p_collect.sh" \
  | rofi \
  -dmenu \
  -i \
  -font "iMWritingDuospace Nerd Font 10" \
  -dpi 240 \
  -markup-rows \
  | "${MY_PATH}/cmd_p_process.sh"
