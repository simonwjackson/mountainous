# Check if the current terminal is kitty
if [ "$TERM" != "xterm-kitty" ]; then
  echo "This script only works with kitty terminal."
  exit 1
fi

preview_image() {
  local filepath="$1"
  if [ -n "$filepath" ]; then
    printf '\033_Ga=d,f=100,i=%s,q=75;2;%s\033\\' "$(realpath "$filepath")" "$(stat --printf="%s" "$filepath")"
  else
    printf '\033_Ga=d;1\033\\'
  fi
}

selected_image="$(find . -type f -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' | fzf --preview 'kitty +kitten icat {}' --preview-window 'right:50%:wrap' --bind 'enter:execute(kitty +kitten icat {})+abort')"

if [ -n "$selected_image" ]; then
  kitty +kitten icat "$selected_image"
fi
