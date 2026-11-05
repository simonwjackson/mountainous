.pragma library
// The period lettermark: the icon an app or launcher gets when it has no
// art in the active theme's own set (docs/plans/desktop-themes/
// desktop-icons.md). One rule for the desktop icons and the tray, so a
// launcher on the desktop and its tray icon draw the same tile. Pure, so
// lettermark.test.js runs it under node; Lettermark.qml draws it.
//
// The look matches the web-app lettermarks that scripts/generate-desktop-
// art.py draws at build time:
//   platinum  a Chi-Nata-style cube (32 art px: 1 px black outline, an
//             upright front face in the tint, a lighter top, a darker
//             side, a soft shadow), a white ChicagoFLF letter on the face;
//   win98     a raised Win98 tile (16 art px, or 32 at desktop size): white
//             and black outer bevel, grey inner shadow, a white W95FA Grid
//             letter struck twice.
//
// API (agreed with the chrome worker, who uses it for tray icons):
//   needs(iconName, resolvedPath[, themeId]) -> bool
//   mark(themeId, label, id) -> { letter, fill, ink, edge, light, dark, shade }
//   colours(themeId, tint) -> the same colours for a given tint
//   art(themeId, colours, grid) -> { grid, rects: [{x, y, w, h, color}], face }
//   gridFor(themeId, size) -> 16 or 32

// The theme's own icon themes: art found anywhere else (hicolor, Adwaita,
// an app's own directory) is not period art.
var OWN = {
    platinum: ["Mountainous-platinum"],
    win98: ["Mountainous-win98", "Chicago95"]
};

// Tints a letter stays legible on in white (each at least 4:1 against
// white). Platinum: muted Mac OS 8/9 accents. Win98: the dark half of the
// VGA palette, as Windows 98 drew its own icons.
var TINTS = {
    platinum: ["#3a6ea5", "#6b4fa0", "#2f7d6d", "#a5462f", "#7d6420", "#3d5a80", "#7a3b69", "#4d6b2f"],
    win98: ["#000080", "#008080", "#800000", "#6b6b00", "#800080", "#008000", "#0000c0"]
};

function themeOf(themeId) {
    return themeId === "win98" ? "win98" : "platinum";
}

// True when the icon has no art in the theme's own set: no name, no
// resolved file (a pixmap-only StatusNotifierItem, a name no theme has),
// a URL that is not a file (an image provider's pixmap), or a file that
// is not under one of the theme's own icon themes (hicolor, Adwaita, an
// app's bundled PNG). Without themeId both themes' sets count as own.
function needs(iconName, resolvedPath, themeId) {
    var name = String(iconName || "");
    var path = String(resolvedPath || "");
    if (name === "" || path === "") return true;
    if (path.indexOf("file://") === 0) path = path.slice(7);
    else if (path.indexOf("://") >= 0) return true;
    try { path = decodeURIComponent(path); } catch (e) { /* keep it raw */ }
    var own = themeId ? OWN[themeOf(themeId)] : OWN.platinum.concat(OWN.win98);
    var m = /\/icons\/([^\/]+)\//.exec(path);
    if (!m) return true;
    return own.indexOf(m[1]) < 0;
}

// The first letter or digit, upper case, else "".
function initial(s) {
    var chars = Array.from(String(s || ""));
    var re;
    try { re = new RegExp("[\\p{L}\\p{N}]", "u"); }
    catch (e) { re = /[A-Za-z0-9\u00C0-\u024F\u0370-\u03FF\u0400-\u04FF]/; }
    for (var i = 0; i < chars.length; i++)
        if (re.test(chars[i])) return chars[i].toUpperCase();
    return "";
}

// FNV-1a over the id: the same app always gets the same tint.
function hash(s) {
    var h = 0x811c9dc5;
    var str = String(s || "");
    for (var i = 0; i < str.length; i++) {
        h ^= str.charCodeAt(i);
        h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h >>> 0;
}

function tintFor(themeId, id) {
    var list = TINTS[themeOf(themeId)];
    return list[hash(id) % list.length];
}

function parse(hex) {
    var s = String(hex || "").replace("#", "");
    if (s.length === 3) s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2];
    if (!/^[0-9a-fA-F]{6}$/.test(s)) s = "808080";
    return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
}
function hex(rgb) {
    return "#" + rgb.map(function (v) { var t = Math.max(0, Math.min(255, Math.round(v))).toString(16); return t.length < 2 ? "0" + t : t; }).join("");
}
// The generator's shade(): toward white (> 0) or black (< 0), truncated.
function shade(colour, amount) {
    var c = parse(colour);
    if (amount > 0) return hex(c.map(function (v) { return Math.floor(v + (255 - v) * amount); }));
    return hex(c.map(function (v) { return Math.floor(v * (1 + amount)); }));
}

// The colours of a tile in this tint. fill: the face; ink: the letter;
// edge: the outline; light/dark: the bevel (Win98) or top/side faces
// (Platinum); shade: the front face's highlight (Platinum) or the inner
// shadow (Win98).
function colours(themeId, tint) {
    var fill = hex(parse(tint));
    if (themeOf(themeId) === "win98")
        return { fill: fill, ink: "#ffffff", edge: "#000000", light: "#ffffff", dark: "#000000", shade: "#808080" };
    return { fill: fill, ink: "#ffffff", edge: "#000000", light: shade(fill, 0.45), dark: shade(fill, -0.35), shade: shade(fill, 0.6) };
}

// The lettermark for an app: label is its display name, id its stable id
// (desktop entry id, window class, SNI id). The tint follows the id, so a
// renamed app keeps its colour.
function mark(themeId, label, id) {
    var letter = initial(label) || initial(id) || "?";
    var key = String(id || "") || String(label || "");
    var c = colours(themeId, tintFor(themeId, key));
    c.letter = letter;
    return c;
}

// The art grid: Platinum is always the 32 px cube; Win98 draws its 16 px
// tile up to 24 logical px and the 32 px one above.
function gridFor(themeId, size) {
    if (themeOf(themeId) === "platinum") return 32;
    return size > 24 ? 32 : 16;
}

// ---- rasterising, in art pixels (the generator's PIL drawing, by hand)

function canvas(n) {
    var g = [];
    for (var y = 0; y < n; y++) { var row = []; for (var x = 0; x < n; x++) row.push(null); g.push(row); }
    return g;
}
function put(g, x, y, c) {
    if (y >= 0 && y < g.length && x >= 0 && x < g.length) g[y][x] = c;
}
function line(g, x0, y0, x1, y1, c) {
    var dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0);
    var sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, err = dx + dy;
    for (;;) {
        put(g, x0, y0, c);
        if (x0 === x1 && y0 === y1) break;
        var e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}
// A convex polygon, filled like PIL: each row between its edges' pixels,
// then the edges (in the outline colour, or the fill).
function polygon(g, pts, fill, outline) {
    var edge = canvas(g.length);
    var i;
    for (i = 0; i < pts.length; i++) {
        var a = pts[i], b = pts[(i + 1) % pts.length];
        line(edge, a[0], a[1], b[0], b[1], true);
    }
    for (var y = 0; y < g.length; y++) {
        var lo = -1, hi = -1;
        for (var x = 0; x < g.length; x++) if (edge[y][x]) { if (lo < 0) lo = x; hi = x; }
        for (x = lo; lo >= 0 && x <= hi; x++) put(g, x, y, edge[y][x] ? (outline || fill) : fill);
    }
}
function rect(g, x0, y0, x1, y1, fill, outline) {
    for (var y = y0; y <= y1; y++) for (var x = x0; x <= x1; x++) put(g, x, y, fill);
    if (outline) {
        line(g, x0, y0, x1, y0, outline); line(g, x0, y1, x1, y1, outline);
        line(g, x0, y0, x0, y1, outline); line(g, x1, y0, x1, y1, outline);
    }
}
// Runs of one colour per row, then runs of equal rows merged downward.
function runs(g) {
    var out = [];
    var open = {};
    for (var y = 0; y < g.length; y++) {
        var next = {};
        var x = 0;
        while (x < g.length) {
            var c = g[y][x];
            if (c === null) { x++; continue; }
            var x0 = x;
            while (x < g.length && g[y][x] === c) x++;
            var key = x0 + ":" + x + ":" + c;
            var r = open[key];
            if (r) { r.h += 1; next[key] = r; }
            else { r = { x: x0, y: y, w: x - x0, h: 1, color: c }; out.push(r); next[key] = r; }
        }
        open = next;
    }
    return out;
}

// The tile without its letter, as rectangles in art pixels, and the box
// the letter is centred in (face: {x, y, w, h}, letter size px).
function art(themeId, c, grid) {
    var g;
    if (themeOf(themeId) === "platinum") {
        // cube() in scripts/generate-desktop-art.py.
        g = canvas(32);
        polygon(g, [[19, 28], [26, 21], [30, 21], [30, 24], [24, 30], [19, 30]], "#50000000");
        polygon(g, [[3, 12], [10, 5], [25, 5], [18, 12]], c.light, c.edge);
        polygon(g, [[18, 12], [25, 5], [25, 20], [18, 27]], c.dark, c.edge);
        rect(g, 3, 12, 18, 27, c.fill, c.edge);
        line(g, 4, 13, 17, 13, c.shade);
        line(g, 4, 13, 4, 26, c.shade);
        return { grid: 32, rects: runs(g), face: { x: 4, y: 14, w: 14, h: 12 }, text: 12, strike: 0 };
    }
    // lettermark_win98() in the generator.
    var n = grid === 32 ? 32 : 16;
    g = canvas(n);
    var inset = n === 16 ? 1 : 2, lo = inset, hi = n - 1 - inset;
    rect(g, lo, lo, hi, hi, c.fill);
    line(g, lo, lo, hi - 1, lo, c.light);
    line(g, lo, lo, lo, hi - 1, c.light);
    line(g, lo, hi, hi, hi, c.dark);
    line(g, hi, lo, hi, hi, c.dark);
    line(g, lo + 1, hi - 1, hi - 1, hi - 1, c.shade);
    line(g, hi - 1, lo + 1, hi - 1, hi - 1, c.shade);
    var k = n / 16;
    return { grid: n, rects: runs(g), face: { x: 0, y: 0, w: n, h: n }, text: 12 * k, strike: k };
}
