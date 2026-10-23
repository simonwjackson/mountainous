# shellcheck shell=bash
# The Win98 Start menu's keyboard model and roll-out, checked through the
# gallery's IPC (page "keys"). Sourced by capture.sh and check.sh, which
# define ipc() and set fail=0; a failed expectation sets fail=1.
# The sequence is the approved mock's checks (REPORT.md, "Checks run").
ipc page keys >/dev/null
sleep 0.5
expect() {   # expect <key|-> <wanted state fragment>
  local got
  if [ "$1" = - ]; then got=$(ipc menu); else got=$(ipc key "$1"); fi
  case "$got" in
    *"$2"*) echo "ok    $1 -> $2" ;;
    *) echo "FAIL  $1 -> wanted '$2', got '$got'"; fail=1 ;;
  esac
}
ipc resetMenu >/dev/null
expect - "path= cursor=-"
expect Down "path= cursor=Programs"
expect Up "path= cursor=Log Off simon..."
ipc resetMenu >/dev/null
expect p "path=Programs cursor=Accessories"
expect Down "path=Programs cursor=Development"
expect Down "path=Programs cursor=Internet"
expect Right "path=Programs/Internet cursor=Chromium"
expect s "path=Programs/Internet cursor=Signal"
expect s "path=Programs/Internet cursor=Sunshine"
expect s "path=Programs/Internet cursor=Syncthing"
expect s "path=Programs/Internet cursor=Signal"
expect Left "path=Programs cursor=Internet"
expect Esc "path= cursor=Programs"
expect Esc "closed=1"
ipc resetMenu >/dev/null
expect Up "path= cursor=Log Off simon..."
expect Enter "triggered=Log Off simon..."
ipc resetMenu >/dev/null
expect s "path=Settings cursor=Display..."
expect b "triggered=Bluetooth"
ipc resetMenu >/dev/null
expect x "ignored"
# Roll-out: 120 ms when motion is allowed, none when reduced.
ipc motion false >/dev/null; ipc resetMenu >/dev/null
r=$(ipc keyReveal p); [ "$r" = 0 ] && echo "ok    roll-out starts at 0" || { echo "FAIL  roll-out did not start ($r)"; fail=1; }
sleep 0.3; r=$(ipc reveal 1); [ "$r" = 1 ] && echo "ok    roll-out done after 300 ms" || { echo "FAIL  roll-out not done ($r)"; fail=1; }
ipc motion true >/dev/null; ipc resetMenu >/dev/null
r=$(ipc keyReveal p); [ "$r" = 1 ] && echo "ok    reduced motion: no roll-out" || { echo "FAIL  reduced motion rolled ($r)"; fail=1; }
ipc motion false >/dev/null
