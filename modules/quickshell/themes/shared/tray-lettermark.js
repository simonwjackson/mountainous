.pragma library
// STAND-IN for modules/quickshell/lettermark.js (the desktop worker's
// period lettermark rule, feat/desktop-icons). Same call signatures:
//   needs(iconName, resolvedPath[, themeId]) -> bool
//   mark(themeId, label, id) -> { letter, fill, ink, edge, light, dark, shade }
// At Integrate the importers switch to "../../lettermark.js" (or
// "lettermark.js" from the shell root) and this file goes.

var OWN = { platinum: ["Mountainous-platinum"], win98: ["Mountainous-win98", "Chicago95"] };
var TINTS = {
    platinum: ["#3a6ea5", "#6b4fa0", "#2f7d6d", "#a5462f", "#7d6420", "#3d5a80"],
    win98: ["#000080", "#008080", "#800000", "#6b6b00", "#800080", "#008000"]
};
function themeOf(t) { return t === "win98" ? "win98" : "platinum"; }

function needs(iconName, resolvedPath, themeId) {
    var name = String(iconName || ""), path = String(resolvedPath || "");
    if (name === "" || path === "") return true;
    if (path.indexOf("file://") === 0) path = path.slice(7);
    else if (path.indexOf("://") >= 0) return true;
    var own = themeId ? OWN[themeOf(themeId)] : OWN.platinum.concat(OWN.win98);
    var m = /\/icons\/([^\/]+)\//.exec(path);
    return !m || own.indexOf(m[1]) < 0;
}

function initial(s) {
    var m = /[A-Za-z0-9]/.exec(String(s || ""));
    return m ? m[0].toUpperCase() : "";
}
function hash(s) {
    var h = 0x811c9dc5, str = String(s || "");
    for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
    return h >>> 0;
}
function mark(themeId, label, id) {
    var t = themeOf(themeId);
    var fill = TINTS[t][hash(String(id || "") || String(label || "")) % TINTS[t].length];
    return { letter: initial(label) || initial(id) || "?", fill: fill, ink: "#ffffff", edge: "#000000",
        light: "#ffffff", dark: "#000000", shade: "#808080" };
}
