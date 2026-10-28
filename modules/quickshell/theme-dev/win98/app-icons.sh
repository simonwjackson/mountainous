#!/usr/bin/env bash
# Chromium and its web apps on the Win98 taskbar and the Platinum Control
# Strip draw the Phase 4 icon set, never Chromium's own logo
# (docs/plans/desktop-themes/small-fixes.md, app-icon.js).
#
# The harness's tb-web state: Chromium by both classes (chromium-browser,
# chromium), the declared --app web app Reddit, the installed PWAs Jellyfin
# and Microsoft Teams, an --app window of an unknown site, and Ghostty, by
# real window class. The session's data directory has what Myoko has:
# Chromium's desktop entry (Icon=chromium), Reddit's (Icon=webapp-reddit),
# and Chromium-written PWA entries whose Icon= is a path to the site's own
# PNG. hicolor holds stand-ins for Chromium's logo (its four colours) and a
# PWA's own icon (magenta), so a lookup that falls through to them shows.
#
# It asserts, in each theme's crop: none of those colours; each lettermark's
# tint (Reddit, Jellyfin, Teams). The crops and full shots go to <out>.
#
#   app-icons.sh <shell dir> <work dir> <out dir>
#
# Needs the patched Quickshell (Quickshell.iconTheme) as qs, the desktop-art
# package and hicolor on XDG_DATA_DIRS, sway, grim and python3 with Pillow.
# checks.app-icons runs it.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:?work dir}")
out=$(realpath -m "${3:?out dir}")
mkdir -p "$work/data/applications" "$out"

jellyfin=lneafpomhdmfgkblnkjeglpppndalpik
teams=ompifgpmddkgmclendfeacglnodjjndh
python3 - "$work/data" "$jellyfin" "$teams" <<'PY'
import sys
from pathlib import Path
from PIL import Image, ImageDraw
data, jellyfin, teams = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
apps = data / "icons/hicolor/32x32/apps"
apps.mkdir(parents=True, exist_ok=True)
# Chromium's logo, as its four flat colours (Win98's old chromium.svg).
logo = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
d = ImageDraw.Draw(logo)
d.pieslice([0, 0, 31, 31], 210, 330, fill="#db4437")
d.pieslice([0, 0, 31, 31], 90, 210, fill="#0f9d58")
d.pieslice([0, 0, 31, 31], -30, 90, fill="#f4b400")
d.ellipse([9, 9, 22, 22], fill="#1a73e8")
logo.save(apps / "chromium.png")
own = Image.new("RGBA", (32, 32), "#ff00ff")
own.save(apps / f"chrome-{jellyfin}-Default.png")
own.save(data / "pwa-own-icon.png")
def entry(name, fields):
    (data / "applications" / f"{name}.desktop").write_text(
        "[Desktop Entry]\nType=Application\nExec=true\n" + "".join(f"{k}={v}\n" for k, v in fields.items()))
entry("chromium-browser", {"Name": "Chromium", "Icon": "chromium", "StartupWMClass": "chromium-browser"})
entry("webapp-reddit", {"Name": "Reddit", "Icon": "webapp-reddit", "StartupWMClass": "chrome-www.reddit.com__-Default"})
for app_id, name in ((jellyfin, "Jellyfin"), (teams, "Microsoft Teams (PWA)")):
    entry(f"chrome-{app_id}-Default", {"Name": name, "Icon": str(data / "pwa-own-icon.png"),
                                       "StartupWMClass": f"crx_{app_id}"})
PY

# shellcheck source=session.sh
. "$here/session.sh" "$shell_dir" "$work" 2880x1800
trap session_stop EXIT
fail=0
for _ in $(seq 60); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
w98 theme light >/dev/null
w98 set tb-web >/dev/null
sleep 2

name() { printf '%s\n' "$1" > "$XDG_STATE_HOME/mountainous/theme-name.new"; mv "$XDG_STATE_HOME/mountainous/theme-name.new" "$XDG_STATE_HOME/mountainous/theme-name"; }
shot "$out/win98-full.png"
name platinum
for _ in $(seq 80); do w98 current | grep -q '"loaded":"platinum"' && break; sleep 0.1; done
sleep 2.5
shot "$out/platinum-full.png"

# Crops (device px, 2880 x 1800 at 1.5): the Win98 taskbar's window
# buttons; the Platinum Control Strip at the bottom left.
python3 - "$out" <<'PY' || fail=1
import sys
from pathlib import Path
from PIL import Image
out = Path(sys.argv[1])
crops = {"win98-taskbar": ("win98-full.png", (0, 1800 - 84, 2880, 1800)),
         "platinum-strip": ("platinum-full.png", (0, 1800 - 120, 1500, 1800))}
banned = {"Chromium red": "#db4437", "Chromium green": "#0f9d58", "Chromium yellow": "#f4b400",
          "Chromium blue": "#1a73e8", "a PWA's own icon": "#ff00ff"}
wanted = {"Reddit": "#ff4500", "Jellyfin": "#0089c2", "Microsoft Teams": "#4b53bc"}
rgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
near = lambda p, c: max(abs(a - b) for a, b in zip(p, c)) <= 6
failed = False
for crop, (full, box) in crops.items():
    image = Image.open(out / full).convert("RGB").crop(box)
    image.save(out / f"{crop}.png")
    colours = image.getcolors(maxcolors=1 << 24)
    for label, colour in banned.items():
        n = sum(count for count, p in colours if near(p, rgb(colour)))
        print(("FAIL" if n else "PASS") + f" {crop}: no {label} ({n} px)")
        failed |= n > 0
    for label, colour in wanted.items():
        n = sum(count for count, p in colours if near(p, rgb(colour)))
        print(("PASS" if n >= 20 else "FAIL") + f" {crop}: {label}'s lettermark ({n} px)")
        failed |= n < 20
sys.exit(1 if failed else 0)
PY

cp "$work/qs.log" "$out/qs.log"
if grep -E 'WARN scene|TypeError|ReferenceError|is not defined|QML.*(Error|Warning)' "$work/qs.log"; then
  echo "FAIL QML warnings (above)"; fail=1
fi
[ "$fail" = 0 ] && echo "APP_ICONS_PASSED: Win98 taskbar and Platinum strip draw the Phase 4 browser icon and lettermarks"
exit "$fail"
