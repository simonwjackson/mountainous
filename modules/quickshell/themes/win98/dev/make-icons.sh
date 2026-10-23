#!/usr/bin/env bash
# Regenerates themes/win98/icons/*.svg from the approved mock's icons.js.
# Development only; nothing installs this. Needs node and the mock at
# /tmp/win98-mock (or MOCK=<dir>).
#
# Colour placeholders, swapped by Win98IconStore.url():
#   #000001       the outline ("ink"): black in light, a mid grey in dark grey
#   currentColor  the text colour of the surface the icon sits on
#   #00ff01       the battery level colour (tone); width 7.77 is its length
set -euo pipefail
mock=${MOCK:-/tmp/win98-mock}
out=$(cd "$(dirname "$0")/.." && pwd)/icons
mkdir -p "$out"
node - "$mock/icons.js" "$out" <<'JS'
const fs = require("fs");
const [src, out] = process.argv.slice(2);
const I = new Function(fs.readFileSync(src, "utf8") + "\nreturn { I, pixelText };")().I;
const files = {
  // Start button and Start menu
  mark: I.mark(), programs: I.programs(), windows: I.windows(), commands: I.commands(), settings: I.settings(),
  run: I.run(), logoff: I.key(), shutdown: I.shutdown(), display: I.display(), scale: I.scale(), folder: I.folder(), doc: I.doc(),
  // Applications (fixtures in the mock; window buttons and Programs)
  term: I.term(), chromium: I.chromium(), firefox: I.firefox(), signal: I.signal(), zed: I.zed(), obs: I.obs(),
  sun: I.sun(), sync: I.sync(), tx: I.tx(),
  // Tray
  "bluetooth-on": I.bt(true), "bluetooth-off": I.bt(false),
  "wifi-0": I.wifi(0, false), "wifi-1": I.wifi(1, false), "wifi-2": I.wifi(2, false), "wifi-3": I.wifi(3, false), "wifi-4": I.wifi(4, false), "wifi-off": I.wifi(0, true),
  "volume-0": I.vol(0, false), "volume-1": I.vol(0.4, false), "volume-2": I.vol(0.8, false), "volume-muted": I.vol(0.4, true),
  brightness: I.bri(),
  "oci-normal": I.oci("normal"), "oci-warning": I.oci("warning"), "oci-danger": I.oci("danger"), "oci-muted": I.oci("muted"),
  "disk-ok": I.disk("ok"), "disk-warn": I.disk("warn"), "disk-bad": I.disk("bad"), "disk-muted": I.disk("muted"),
  bell: I.bell(false), "bell-muted": I.bell(true),
  battery: I.bat(77.7, "normal", ""), "battery-bolt": I.bat(77.7, "normal", "bolt"), "battery-plug": I.bat(77.7, "normal", "plug"),
  "mic-recording": I.mic("recording"), "mic-working": I.mic("working"), "mic-failed": I.mic("failed"),
  builder: I.builder({}), "builder-grey": I.builder({ grey: true }), "builder-off": I.builder({ off: true }),
  "builder-off-grey": I.builder({ off: true, grey: true }), "builder-wait": I.builder({ wait: true }),
  "builder-warn": I.builder({ warn: true }), "builder-unknown": I.builder({ unknown: true, grey: true }),
  hourglass: I.hourglass(), host: I.host(),
  // Status marks
  ok: I.okmark(), warn: I.warnmark(), bad: I.badmark(), lock: I.lock(), dot: I.dot(), ring: I.ring(),
  // Marlett's glyphs: caption buttons, arrows, check
  close: I.x(), help: I.q(), check: I.check(), "arrow-right": I.right(), "arrow-down": I.down(), "arrow-up": I.up(), chevron: I.chev(),
};
files["arrow-left"] = files["arrow-right"].replace('<path d="M0 0h1v1h1v1h1v1h1v1h-1v1h-1v1h-1v1h-1z"', '<path d="M4 0h-1v1h-1v1h-1v1h-1v1h1v1h1v1h1v1h1z"');
for (const [name, svg0] of Object.entries(files)) {
  let svg = svg0.replace(/var\(--ink\)/g, "#000001")
    .replace(/ class="crisp"/, ' shape-rendering="crispEdges"')
    .replace("<svg ", '<svg xmlns="http://www.w3.org/2000/svg" ');
  if (name.startsWith("battery")) svg = svg.replace('width="6.22"', 'width="7.77"').replace(/fill="#00a000"/, 'fill="#00ff01"');
  fs.writeFileSync(`${out}/${name}.svg`, svg + "\n");
}
console.log(Object.keys(files).length + 1, "icons");
JS
