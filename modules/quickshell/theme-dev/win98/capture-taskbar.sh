#!/usr/bin/env bash
# Screenshots of the taskbar and session pieces, named after the parity
# mock's states (/tmp/tandem/win98-parity-mock/shots/states/), for the
# side-by-side compare. Development only; not run by a check.
#
#   capture-taskbar.sh <shell dir> <out dir> [WxH logical, default 1920x1200] [light|dark]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
out=$(realpath -m "${2:?out dir}")
size=${3:-1920x1200}
mode=${4:-light}
w=${size%x*}; h=${size#*x}
mkdir -p "$out"
# shellcheck source=session.sh
. "$here/session.sh" "$shell_dir" "$out/session-$size-$mode" "$(( w * 3 / 2 ))x$(( h * 3 / 2 ))"
trap session_stop EXIT
for _ in $(seq 60); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
w98 theme "$mode" >/dev/null
tag=$([ "$mode" = light ] && echo light || echo grey)
name() { echo "$out/$1-$tag-${size}.png"; }
fresh() { w98 closeAll >/dev/null; w98 lists full >/dev/null; w98 set "${1:-tb-normal}" >/dev/null; sleep 1.2; }
seq=$(( $(date +%s) % 100000 * 100 ))

fresh; w98 openMenu start >/dev/null; sleep 0.8; shot "$(name s-start)"
fresh; w98 openMenu shutdown >/dev/null; sleep 0.8; shot "$(name s-shut)"
w98 setShutChoice restart >/dev/null; sleep 0.4; shot "$(name s-shut-restart)"
fresh; w98 openMenu start >/dev/null; sleep 0.6; w98 cascade 5 >/dev/null; sleep 0.6; shot "$(name p-start)"
fresh; w98 openMenu sysprops >/dev/null; sleep 1; shot "$(name p-sys)"
fresh; x=$(w98 places | python3 -c 'import json,sys; d=json.load(sys.stdin); print(round(d.get("win1", d.get("start", {"x": 4}))["x"]))')
w98 windowMenu 1001 "$x" "$(( h - 28 ))" >/dev/null; sleep 0.6; w98 cascade 1 >/dev/null; sleep 0.6; shot "$(name h-btnmenu)"
fresh; w98 taskbarMenu $(( w * 2 / 3 )) >/dev/null; sleep 0.6; shot "$(name h-tbmenu)"
fresh; w98 perform minimizeOthers >/dev/null; sleep 0.6; shot "$(name h-others)"
fresh; w98 perform minimizeAll >/dev/null; sleep 0.6; w98 taskbarMenu $(( w * 2 / 3 )) >/dev/null; sleep 0.6; shot "$(name h-minall)"
fresh; w98 perform minimizeOthers >/dev/null; sleep 0.4; w98 openMenu start >/dev/null; sleep 0.6; w98 cascade 3 >/dev/null; sleep 0.6; shot "$(name h-start-windows)"
fresh tb-many; seq=$((seq + 1)); w98 cycle step 4 "$seq" >/dev/null; sleep 0.8; shot "$(name c-windows)"
seq=$((seq + 1)); w98 cycle cancel 0 "$seq" >/dev/null
fresh; w98 openMenu start >/dev/null; sleep 0.6; w98 cascade 1 >/dev/null; sleep 0.6; shot "$(name r-favorites)"
fresh; w98 openMenu start >/dev/null; sleep 0.6; w98 cascade 2 >/dev/null; sleep 0.6; shot "$(name r-recent)"
fresh; w98 lists empty >/dev/null; sleep 0.3; w98 openMenu start >/dev/null; sleep 0.6; w98 cascade 2 >/dev/null; sleep 0.6; shot "$(name r-empty)"
fresh; sleep 2.2; w98 setVolume 43 >/dev/null; sleep 0.4; shot "$(name v-vol)"
sleep 2; w98 setBrightness 60 >/dev/null; w98 setBrightness 61 >/dev/null; sleep 0.4; shot "$(name v-bri)"
fresh tb-chord; sleep 0.4; shot "$(name k-chord)"
w98 strings > "$out/strings-$tag-$size.json"
cp "$out/session-$size-$mode/qs.log" "$out/qs-$tag-$size.log"
