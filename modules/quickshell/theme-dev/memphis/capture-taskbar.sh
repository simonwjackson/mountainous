#!/usr/bin/env bash
# Screenshots of the taskbar and session pieces, named after the parity
# mock's states (/tmp/tandem/memphis-parity-mock/shots/states/), for the
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
for _ in $(seq 60); do memphis current | grep -q '"loaded":"memphis"' && break; sleep 0.2; done
memphis theme "$mode" >/dev/null
tag=$([ "$mode" = light ] && echo light || echo grey)
name() { echo "$out/$1-$tag-${size}.png"; }
fresh() { memphis closeAll >/dev/null; memphis lists full >/dev/null; memphis set "${1:-tb-normal}" >/dev/null; sleep 1.2; }
seq=$(( $(date +%s) % 100000 * 100 ))

fresh; memphis openMenu start >/dev/null; sleep 0.8; shot "$(name s-start)"
fresh; memphis openMenu shutdown >/dev/null; sleep 0.8; shot "$(name s-shut)"
memphis setShutChoice restart >/dev/null; sleep 0.4; shot "$(name s-shut-restart)"
fresh; memphis openMenu start >/dev/null; sleep 0.6; memphis cascade 5 >/dev/null; sleep 0.6; shot "$(name p-start)"
fresh; memphis openMenu sysprops >/dev/null; sleep 1; shot "$(name p-sys)"
fresh; x=$(memphis places | python3 -c 'import json,sys; d=json.load(sys.stdin); print(round(d.get("win1", d.get("start", {"x": 4}))["x"]))')
memphis windowMenu 1001 "$x" "$(( h - 28 ))" >/dev/null; sleep 0.6; memphis cascade 1 >/dev/null; sleep 0.6; shot "$(name h-btnmenu)"
fresh; memphis taskbarMenu $(( w * 2 / 3 )) >/dev/null; sleep 0.6; shot "$(name h-tbmenu)"
fresh; memphis perform minimizeOthers >/dev/null; sleep 0.6; shot "$(name h-others)"
fresh; memphis perform minimizeAll >/dev/null; sleep 0.6; memphis taskbarMenu $(( w * 2 / 3 )) >/dev/null; sleep 0.6; shot "$(name h-minall)"
fresh; memphis perform minimizeOthers >/dev/null; sleep 0.4; memphis openMenu start >/dev/null; sleep 0.6; memphis cascade 3 >/dev/null; sleep 0.6; shot "$(name h-start-windows)"
fresh tb-many; seq=$((seq + 1)); memphis cycle step 4 "$seq" >/dev/null; sleep 0.8; shot "$(name c-windows)"
seq=$((seq + 1)); memphis cycle cancel 0 "$seq" >/dev/null
fresh; memphis openMenu start >/dev/null; sleep 0.6; memphis cascade 1 >/dev/null; sleep 0.6; shot "$(name r-favorites)"
fresh; memphis openMenu start >/dev/null; sleep 0.6; memphis cascade 2 >/dev/null; sleep 0.6; shot "$(name r-recent)"
fresh; memphis lists empty >/dev/null; sleep 0.3; memphis openMenu start >/dev/null; sleep 0.6; memphis cascade 2 >/dev/null; sleep 0.6; shot "$(name r-empty)"
fresh; sleep 2.2; memphis setVolume 43 >/dev/null; sleep 0.4; shot "$(name v-vol)"
sleep 2; memphis setBrightness 60 >/dev/null; memphis setBrightness 61 >/dev/null; sleep 0.4; shot "$(name v-bri)"
fresh tb-chord; sleep 0.4; shot "$(name k-chord)"
memphis strings > "$out/strings-$tag-$size.json"
cp "$out/session-$size-$mode/qs.log" "$out/qs-$tag-$size.log"
