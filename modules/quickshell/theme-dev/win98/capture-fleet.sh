#!/usr/bin/env bash
# Screenshots of the real Win98 Fleet window and glance space, headless
# (session.sh), for review beside the approved mock pass 2
# (/tmp/win98-hud-mock/shots). Development only; nothing installs this.
#
#   modules/quickshell/theme-dev/win98/capture-fleet.sh <shell dir> <outdir> [group ...]
#
# Groups: standalone, glance, sizes, motion (default: all). Writes PNGs in
# physical px under <outdir>/<group>/ and a log of QML warnings. Tools come
# from PATH, as session.sh needs them.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
out=$(realpath -m "${2:?outdir}")
shift 2
groups=${*:-standalone glance sizes motion}
mkdir -p "$out"
: > "$out/warnings.log"

settle() { sleep "${1:-1.2}"; }
fleet() { w98 fleetFixture "$1" >/dev/null; settle 1.4; [ "$1" = stale ] && settle 1.2; true; }
setv() { w98 fleetSet "$1" "$2" >/dev/null; settle 0.6; }
call() { w98 fleetCall "$1" >/dev/null; settle 0.9; }
look() {   # look light|grey
  w98 theme "$([ "$1" = grey ] && echo dark || echo light)" >/dev/null
  swaymsg -q output HEADLESS-1 bg "$([ "$1" = grey ] && echo '#000000' || echo '#008080')" solid_color
  settle 0.8
}
start() {   # start <logical W> <logical H> [scale]
  local scale=${3:-1.5}
  # shellcheck source=session.sh
  SESSION_SCALE=$scale . "$here/session.sh" "$shell_dir" "$out/session-$1x$2" "$(python3 -c "print(round($1 * $scale), end='x'); print(round($2 * $scale))")"
  for _ in $(seq 60); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
  w98 set tb-normal >/dev/null
  settle 2
}
stop() {
  grep -E "WARN scene|TypeError|ReferenceError" "$(ls -d "$out"/session-* | tail -1)/qs.log" >> "$out/warnings.log" || true
  session_stop
}

if [[ " $groups " == *" standalone "* ]]; then
  mkdir -p "$out/standalone"
  start 1920 1200
  for a in light grey; do
    look "$a"
    for fx in live healthy unzen-problem vm-no-sensor desktop-down server-down stale rakku-down error loading stress empty; do
      fleet "$fx"
      call toggleFleet
      shot "$out/standalone/$a-$fx.png"
      call toggleFleet
    done
    fleet unzen-problem
    call toggleFleet
    for tab in 0 1 2 3; do
      setv tab "$tab"; setv expanded unzen
      shot "$out/standalone/$a-unzen-tab$tab.png"
    done
    setv expanded ""; setv view icons
    shot "$out/standalone/$a-large-icons.png"
    setv view details; setv sort status
    shot "$out/standalone/$a-sorted-status.png"
    setv sort name; setv minimized true
    shot "$out/standalone/$a-minimized.png"
    setv minimized false
    call toggleFleet
    fleet server-down; call toggleFleet; setv tab 0; setv expanded tate
    shot "$out/standalone/$a-tate-down-general.png"
    setv expanded ""; call toggleFleet
    fleet stress; call toggleFleet; setv tab 2; setv expanded unzen
    shot "$out/standalone/$a-stress-unzen-services.png"
    setv tab 3
    shot "$out/standalone/$a-stress-unzen-disks.png"
    setv expanded ""; call toggleFleet
    fleet unzen-problem
  done
  stop
fi

if [[ " $groups " == *" glance "* ]]; then
  mkdir -p "$out/glance"
  start 1920 1200
  for a in light grey; do
    look "$a"
    for fx in live unzen-problem server-down stress loading empty; do
      fleet "$fx"
      call toggleGlance
      shot "$out/glance/$a-$fx.png"
      call toggleGlance
    done
    fleet unzen-problem
    call toggleGlance
    setv tab 1; setv expanded unzen
    shot "$out/glance/$a-unzen-performance.png"
    setv expanded ""
    w98 openMenu glance >/dev/null; settle 0.8
    shot "$out/glance/$a-glance-menu.png"
    w98 closeAll >/dev/null; settle 0.4
    setv enabled fleet:false; setv enabled disks:false
    shot "$out/glance/$a-space-empty.png"
    setv enabled fleet:true; setv enabled disks:true
    setv place disks:400:200
    shot "$out/glance/$a-remembered.png"
    setv cleanup x
    setv view icons
    shot "$out/glance/$a-large-icons.png"
    setv view details
    call toggleGlance
  done
  stop
fi

if [[ " $groups " == *" sizes "* ]]; then
  mkdir -p "$out/sizes"
  for spec in 360x640:1.5 800x480:1.5 1280x800:1.5 1920x1200:1.5 1280x800:2; do
    size=${spec%:*}; scale=${spec#*:}
    w=${size%x*}; h=${size#*x}
    name=$size; [ "$scale" = 2 ] && name=2560x1600-tablet
    start "$w" "$h" "$scale"
    swaymsg -q output HEADLESS-1 bg '#008080' solid_color
    call toggleFleet
    shot "$out/sizes/standalone-$name.png"
    setv expanded unzen
    shot "$out/sizes/standalone-$name-unzen-open.png"
    setv expanded ""; call toggleFleet
    call toggleGlance
    shot "$out/sizes/glance-$name.png"
    setv expanded unzen
    shot "$out/sizes/glance-$name-unzen-open.png"
    setv expanded ""; call toggleGlance
    fleet stress
    call toggleFleet
    shot "$out/sizes/standalone-$name-stress.png"
    call toggleFleet
    stop
  done
fi

if [[ " $groups " == *" motion "* ]]; then
  mkdir -p "$out/motion"
  start 1920 1200
  swaymsg -q output HEADLESS-1 bg '#008080' solid_color
  # Shown first, so the Glance button stands where the captions start.
  call toggleGlance
  for dir in in out; do
    for k in 0 1 2 3 4 5 6 7 8 9 10; do
      w98 seek "$(python3 -c "print(int($k * 1000 / 60 + 1))")" "$dir" >/dev/null; settle 0.5
      shot "$out/motion/$dir-$(printf %02d "$k").png"
    done
  done
  w98 seek -1 in >/dev/null; settle 0.4
  call toggleGlance
  stop
fi
echo "warnings: $(wc -l < "$out/warnings.log") ($out/warnings.log)"
