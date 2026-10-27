#!/usr/bin/env bash
# Adds the taskbar and session icons to themes/win98/icons/ from the
# approved parity mock's icons (/tmp/tandem/win98-parity-mock, icons.js
# and icons2.js), with the same colour placeholders as make-icons.sh.
# Development only; nothing installs this. Needs node and the mock (or
# MOCK=<dir>).
set -euo pipefail
mock=${MOCK:-/tmp/tandem/win98-parity-mock}
out=$(cd "$(dirname "$0")/.." && pwd)/icons
node - "$mock/icons.js" "$mock/icons2.js" "$out" <<'JS'
const fs = require("fs");
const [a, b, out] = process.argv.slice(2);
const I = new Function(fs.readFileSync(a, "utf8") + "\n" + fs.readFileSync(b, "utf8") + "\nreturn I;")();
const files = {
  // Start: Favorites and Documents (24 u), Lock (24 u)
  favorites: I.favorites(), documents: I.recent(), "lock-computer": I.lock24(),
  // Shut Down's computer (32 u) and System Properties' picture (96 x 84 u)
  computer: I.computer32(), system: I.sysPic(),
  // The window menu's glyphs (Marlett's), in the text colour
  maximize: I.gMax(), restore: I.gRestore(),
};
for (const [name, svg0] of Object.entries(files)) {
  let svg = svg0.replace(/var\(--ink\)/g, "#000001")
    .replace(/ class="crisp"/, ' shape-rendering="crispEdges"')
    .replace("<svg ", '<svg xmlns="http://www.w3.org/2000/svg" ');
  svg = svg.replace(/stroke="#000(000)?"/g, 'stroke="#000001"');
  fs.writeFileSync(`${out}/${name}.svg`, svg + "\n");
}
console.log(Object.keys(files).length, "icons");
JS
