# shellcheck shell=bash
# Access keys keep the spaces around them. The parity mock dropped the space
# before or after an underlined letter ("LockMyoko", "MinimizeOther"); this
# checks that Win98Text draws "Loc&k Myoko" as "Lock Myoko", underlines the
# k, and keeps the space's advance, in the label and in the drawn run.
# Sourced by check.sh, which defines ipc() and fail.
access_check() {   # access_check <label> <bold> <plain> <index>
  local got
  got=$(ipc access "$1" "$2")
  if printf '%s' "$got" | python3 -c '
import json, sys
g = json.loads(sys.stdin.read()); want, idx = sys.argv[1], int(sys.argv[2]); e = 0.01
ok = g["plain"] == want and g["drawn"] == want and g["index"] == idx
# The underline starts after every letter and space before the key ...
ok = ok and abs(g["x"] - g["prefix"]) < e and g["w"] > 0
if want[:idx].endswith(" "): ok = ok and g["x"] > g["prefixTrimmed"] + e
# ... and the drawn run is as wide as the label with its spaces.
ok = ok and abs(g["drawnWidth"] - g["whole"]) <= g["u"] + e
if " " in want: ok = ok and g["whole"] > g["squeezed"] + e
sys.exit(0 if ok else 1)' "$3" "$4"; then
    echo "ok    access '$1' -> '$3' key $4"
  else
    echo "FAIL  access '$1' -> wanted '$3' key $4, got $got"; fail=1
  fi
}
access_check "Loc&k Myoko" false "Lock Myoko" 3
access_check "Lock &Myoko" false "Lock Myoko" 5
access_check "Minimize &Other Windows" false "Minimize Other Windows" 9
access_check "&Log Off simon..." false "Log Off simon..." 0
access_check "Restore &All Windows" true "Restore All Windows" 8
access_check "Sh&ut Down..." false "Shut Down..." 2
access_check "Rock && &Roll" false "Rock & Roll" 7
