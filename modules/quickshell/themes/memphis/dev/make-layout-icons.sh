#!/usr/bin/env bash
# Adds the Layout control's icons to themes/memphis/icons/ from the approved
# Layout mock (/tmp/layout-mock/app.js): the tray glyphs (memphisGlyph) and the
# capacity buttons' pictures (memphisPicto), with the same colour placeholders
# as make-icons.sh. Development only; nothing installs this. Needs node and
# the mock (or MOCK=<dir>).
#
#   layout-tile-1, -2, -3, layout-float   16 x 16 u, the tray (PageLayout.glyph)
#   layout-picto-1, -2, -3               30 x 20 u, the "Windows on this page" buttons
#   layout-picto-1-off, ...              the same, greyed, for a Floating page
set -euo pipefail
mock=${MOCK:-/tmp/layout-mock}
out=$(cd "$(dirname "$0")/.." && pwd)/icons
node - "$mock/app.js" "$out" <<'JS'
const fs = require("fs");
const [src, out] = process.argv.slice(2);
// The two drawing functions and their helper, cut from the mock as written.
const text = fs.readFileSync(src, "utf8");
const cut = (name) => {
  const at = text.indexOf("function " + name + "(");
  if (at < 0) throw new Error("no " + name + " in " + src);
  let depth = 0, i = text.indexOf("{", at);
  for (; i < text.length; i++) { if (text[i] === "{") depth++; else if (text[i] === "}" && --depth === 0) break; }
  return text.slice(at, i + 1);
};
const lib = new Function(cut("memphisGlyph") + "\n" + cut("tilesOf") + "\n" + cut("memphisPicto") + "\nreturn { memphisGlyph, memphisPicto };")();
// Greys for a disabled picture: each colour's luminance (the mock's
// grayscale(1) filter); the item draws it at half opacity (opacity(.5)).
const grey = (hex) => {
  const n = parseInt(hex.slice(1).replace(/^(.)(.)(.)$/, "$1$1$2$2$3$3"), 16);
  const y = Math.round(0.2126 * (n >> 16) + 0.7152 * ((n >> 8) & 255) + 0.0722 * (n & 255));
  return "#" + y.toString(16).padStart(2, "0").repeat(3);
};
// The tray glyphs' black outlines become ink, so they read on the dark
// grey bar too. A picture keeps black: its windows stand on its own teal.
const clean = (svg, ink) => {
  const s = svg.replace(/ style="[^"]*"/, "").replace("<svg ", '<svg xmlns="http://www.w3.org/2000/svg" ');
  return ink ? s.replace(/fill="#000"/g, 'fill="#000001"') : s;
};
const files = {
  "layout-tile-1": lib.memphisGlyph(1), "layout-tile-2": lib.memphisGlyph(2), "layout-tile-3": lib.memphisGlyph(3), "layout-float": lib.memphisGlyph(0),
};
for (const n of [1, 2, 3]) {
  files["layout-picto-" + n] = lib.memphisPicto(n, false);
  files["layout-picto-" + n + "-off"] = lib.memphisPicto(n, false).replace(/fill="(#[0-9a-fA-F]{3,6})"/g, (m, c) => c === "#000" ? m : 'fill="' + grey(c) + '"');
}
for (const [name, svg] of Object.entries(files)) fs.writeFileSync(`${out}/${name}.svg`, clean(svg, !name.startsWith("layout-picto")) + "\n");
console.log(Object.keys(files).length, "icons");
JS
