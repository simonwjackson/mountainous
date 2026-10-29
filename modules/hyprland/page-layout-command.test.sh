#!/usr/bin/env bash
set -euo pipefail
script=$1
tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT
export CALLS="$tmp/calls" REPLY=ok
printf '#!%s\n' "$(command -v bash)" > "$tmp/hyprctl"
cat >> "$tmp/hyprctl" <<'SH'
printf '%s\n' "$*" >> "$CALLS"
printf '%s\n' "$REPLY"
SH
chmod +x "$tmp/hyprctl"
export PATH="$tmp:$PATH"
valid() {
  : > "$CALLS"
  bash -euo pipefail "$script" "$@"
  [[ $(wc -l < "$CALLS") -eq 1 ]]
  grep -q '^--instance 0 eval require("page-layout")\.' "$CALLS"
}
invalid() {
  : > "$CALLS"
  if bash -euo pipefail "$script" "$@" > /dev/null 2>&1; then
    printf 'unexpected success: %s\n' "$*" >&2; exit 1
  fi
  [[ ! -s "$CALLS" ]]
}
valid page active cap=2 floating=false gap=10 zen=true
grep -Fq 'page("active",{cap=2,floating=false,gap=10,zen=true,})' "$CALLS"
valid page 2
valid default DP-1 cap=3 gap=-8 floating=true
valid page-default 4 all
valid page-default active gap
valid reset eDP-1
valid step-gap active -4
valid toggle-floating 8
invalid
invalid page
invalid page 0 cap=2
invalid page -2
invalid page active cap=4
invalid page active floating=1
invalid page active zen=yes
invalid page active gap=nan
invalid page active 'gap=1;error("injected")'
invalid page active cap=2 cap=3
invalid default DP-1 zen=true
invalid default 'DP-1");error("injected")' cap=1
invalid page-default 1 zen
invalid page-default 1 all extra
invalid reset DP-1 extra
invalid step-gap 1 '4);error("injected")'
invalid toggle-floating active extra
invalid nonsense active
REPLY='error: no page'
export REPLY
if bash -euo pipefail "$script" page 999 cap=1; then
  echo 'hyprctl Lua failure was not propagated' >&2; exit 1
fi
printf 'page-layout command: all tests passed\n'
