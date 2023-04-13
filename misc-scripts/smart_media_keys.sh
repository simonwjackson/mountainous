# Check if an application is playing audio
is_playing_audio() {
  pactl list sink-inputs | grep -q "application.name = \"$1\""
}

# Send command to mpc
send_mpc_command() {
  case "$1" in
    "XF86AudioPlay")
      nix-shell -p mpc-cli --run "mpc toggle"
      ;;
    "XF86AudioNext")
      mpc next
      ;;
    "XF86AudioPrev")
      mpc prev
      ;;
  esac
}

# Send command to mpv using JSON IPC
send_mpv_command() {
  SOCKET_PATH="/tmp/mpv.socket"

  case "$1" in
    "XF86AudioPlay")
      echo '{ "command": ["cycle", "pause"] }' | socat - UNIX-CONNECT:"$SOCKET_PATH"
      ;;
    "XF86AudioNext")
      echo '{ "command": ["playlist-next"] }' | socat - UNIX-CONNECT:"$SOCKET_PATH"
      ;;
    "XF86AudioPrev")
      echo '{ "command": ["playlist-prev"] }' | socat - UNIX-CONNECT:"$SOCKET_PATH"
      ;;
  esac
}

# Send keypress to the application
send_keypress() {
  WID=$(xdotool search --class "$1" | head -n 1)
  xdotool key --window "$WID" "$2"
}

# Check applications and send keypresses
if is_playing_audio "Music Player Daemon"; then
  send_mpc_command "$1"
elif is_playing_audio "mpv"; then
  send_mpv_command "$1"
elif is_playing_audio "Firefox"; then
  echo "Firefox"
  send_keypress "firefox" "$1"
else
  echo "No matching application found playing audio."
fi
