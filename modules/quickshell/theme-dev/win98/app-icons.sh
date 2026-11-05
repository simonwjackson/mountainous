#!/usr/bin/env bash
# Per-window icons on the real Win98 taskbar and Platinum Control Strip.
# Site/installed icons win; without either, theme art (including PWA
# lettermarks) wins. Each window is compared with its own PNG, so a missing
# or swapped icon cannot pass via a neighbour's colour. The Platinum helper
# must run and its finished token must draw 1:1, not the raw site PNG.
#
#   app-icons.sh <shell dir> <work dir> <out dir>
#
# Needs the patched qs, desktop-art as DESKTOP_ART and on XDG_DATA_DIRS,
# MOUNTAINOUS_PLATINUM_ICON, session.sh's tools and Python with Pillow.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:?work dir}")
out=$(realpath -m "${3:?out dir}")
mkdir -p "$work" "$out"
fail=0

# Geometry from the production plan, not a second strip layout.
node -e '
  const fs = require("node:fs"), vm = require("node:vm");
  const P = { PageNames: {} };
  vm.runInNewContext(fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library\s*$/m, "").replace(/^\.import .*$/m, ""), P);
  console.log(JSON.stringify({ tile: P.tileGeometry(1.5),
    slots: P.slots(Array.from({ length: 7 }, () => ({ page: 1 }))).slots.map(s => s.x),
    CAP: P.CAP, HEIGHT: P.HEIGHT, BOTTOM: P.BOTTOM, TILE_H: P.TILE_H }));
' "$shell_dir/themes/platinum/strip-plan.js" > "$work/strip.json"

name() { printf '%s\n' "$1" > "$XDG_STATE_HOME/mountainous/theme-name.new"; mv "$XDG_STATE_HOME/mountainous/theme-name.new" "$XDG_STATE_HOME/mountainous/theme-name"; }
for mode in site fallback; do
  case_work="$work/$mode"
  case_out="$out/$mode"
  mkdir -p "$case_work" "$case_out"
  export HOME="$case_work"
  python3 "$here/app-icons-fixtures.py" "$case_work" "$mode" > "$case_work/http.log" 2>&1 &
  fixture_pid=$!
  trap 'kill "$fixture_pid" 2>/dev/null || true' EXIT
  for _ in $(seq 100); do [ -f "$case_work/ready" ] && break; sleep 0.1; done
  test -f "$case_work/ready" || { cat "$case_work/http.log"; exit 1; }

  # shellcheck source=session.sh
  . "$here/session.sh" "$shell_dir" "$case_work" 2880x1800
  trap 'kill "$fixture_pid" 2>/dev/null || true; session_stop' EXIT
  for _ in $(seq 60); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
  w98 theme light >/dev/null
  w98 set tb-web >/dev/null
  sleep 4
  w98 places > "$case_work/places.json"
  shot "$case_out/win98-full.png"
  name platinum
  for _ in $(seq 80); do w98 current | grep -q '"loaded":"platinum"' && break; sleep 0.1; done
  sleep 4
  shot "$case_out/platinum-full.png"
  cp "$work/strip.json" "$case_work/strip.json"
  python3 "$here/app-icons.py" "$case_work" "$case_out" "$mode" || fail=1
  cp "$case_work/qs.log" "$case_out/qs.log"
  cp "$case_work/http.log" "$case_out/http.log"
  if grep -E 'WARN scene|TypeError|ReferenceError|is not defined|QML.*(Error|Warning)' "$case_work/qs.log"; then
    echo "FAIL QML warnings (above)"; fail=1
  fi
  kill "$fixture_pid" 2>/dev/null || true
  session_stop
  trap - EXIT
done
[ "$fail" = 0 ] && echo "APP_ICONS_PASSED: per-window site/installed icons, Platinum tokens and theme-art fallbacks"
exit "$fail"
