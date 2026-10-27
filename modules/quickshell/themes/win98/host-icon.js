.pragma library
// The Fleet views' host icon, ported from the approved mock (fleet98.js
// hostIcon): a computer at 16 or 32 u. Shape says the status, the overlay
// says the tone, as the mock's DIRECTION.md sets it:
//   up       a lit screen          down     a dark screen and a cross
//   paused   two bars on the screen pending  an hourglass
//   danger   a red stop circle     warning  a yellow triangle
//   muted    the whole computer drawn through a 50% checker (Win98's "cut")
// The overlay sits at the bottom left, where Win98 drew the shortcut arrow.
//
// The computer is pixel art: it is drawn into a grid and written out as one
// 1-u rect per run, so the muted checker and the selected tint need no SVG
// mask or pattern (Qt's SVG renderer has neither). The overlays are small
// vector shapes, antialiased as the mock's are.
//
// svg(status, tone, size, selected, colors): markup with a viewBox in units.
// colors: { selection } (the selected tint over the Large Icons computer).

function rects(status, big) {
    var lit = status === "up";
    var scr = lit ? "#008080" : "#000000";
    var R = function (x, y, w, h, f) { return [x, y, w, h, f]; };
    var out;
    if (big) {
        out = [R(5, 1, 22, 19, "#000"), R(5, 1, 21, 18, "#fff"), R(6, 2, 19, 16, "#808080"), R(6, 2, 19, 15, "#c0c0c0"),
            R(8, 4, 16, 12, "#808080"), R(9, 5, 15, 11, "#fff"), R(9, 5, 14, 10, scr)];
        if (lit) out.push(R(10, 6, 4, 1, "#00c0c0"), R(10, 7, 1, 2, "#00c0c0"));
        if (status === "paused") out.push(R(13, 7, 2, 6, "#fff"), R(17, 7, 2, 6, "#fff"));
        out.push(R(12, 20, 8, 2, "#000"), R(14, 20, 4, 1, "#808080"), R(2, 22, 28, 9, "#000"), R(2, 22, 27, 8, "#fff"),
            R(3, 23, 26, 7, "#808080"), R(3, 23, 25, 6, "#c0c0c0"), R(17, 25, 9, 1, "#000"), R(17, 26, 9, 1, "#fff"),
            R(5, 26, 2, 1, lit ? "#00ff00" : "#404040"));
    } else {
        out = [R(3, 0, 11, 10, "#000"), R(3, 0, 10, 9, "#fff"), R(4, 1, 9, 8, "#c0c0c0"), R(5, 2, 7, 5, scr)];
        if (status === "paused") out.push(R(7, 3, 1, 3, "#fff"), R(9, 3, 1, 3, "#fff"));
        out.push(R(6, 10, 5, 1, "#000"), R(1, 11, 15, 5, "#000"), R(1, 11, 14, 4, "#fff"), R(2, 12, 13, 3, "#c0c0c0"),
            R(9, 13, 4, 1, "#000"), R(3, 13, 1, 1, lit ? "#00ff00" : "#404040"));
    }
    return out;
}

// The computer as a grid of colours ("" is clear), size x size.
function grid(status, size) {
    var big = size >= 32;
    var g = [];
    for (var y = 0; y < size; y++) { var row = []; for (var x = 0; x < size; x++) row.push(""); g.push(row); }
    var list = rects(status, big);
    for (var i = 0; i < list.length; i++) {
        var r = list[i];
        for (var yy = r[1]; yy < r[1] + r[3] && yy < size; yy++)
            for (var xx = r[0]; xx < r[0] + r[2] && xx < size; xx++) g[yy][xx] = r[4];
    }
    return g;
}

// Muted: only the pixels where x + y is even stay (the mock's mask).
// Selected: the selection colour on the same half of the computer.
function shade(g, muted, selected, selection) {
    for (var y = 0; y < g.length; y++) for (var x = 0; x < g[y].length; x++) {
        if (g[y][x] === "") continue;
        var even = (x + y) % 2 === 0;
        if (muted && !even) g[y][x] = "";
        else if (selected && even) g[y][x] = selection;
    }
    return g;
}

function runs(g) {
    var out = "";
    for (var y = 0; y < g.length; y++) {
        var x = 0;
        while (x < g[y].length) {
            var c = g[y][x];
            var x2 = x + 1;
            while (x2 < g[y].length && g[y][x2] === c) x2++;
            if (c !== "") out += '<rect x="' + x + '" y="' + y + '" width="' + (x2 - x) + '" height="1" fill="' + c + '"/>';
            x = x2;
        }
    }
    return out;
}

function overlay(status, tone, size) {
    var B = size >= 32 ? 13 : 8, oy = size - B;
    var open = '<g transform="translate(0 ' + oy + ') scale(' + (B / 13) + ')">';
    if (status === "down") {
        var c = tone === "danger" ? "#ff0000" : "#000000", e = tone === "danger" ? "#800000" : "#808080";
        return open + '<path d="M0 0 L3 0 L6.5 3.5 L10 0 L13 0 L13 3 L9.5 6.5 L13 10 L13 13 L10 13 L6.5 9.5 L3 13 L0 13 L0 10 L3.5 6.5 L0 3 Z" fill="'
            + c + '" stroke="' + e + '" stroke-width="1"/></g>';
    }
    if (status === "pending" || status === "loading")
        return open + '<path d="M1 0.5 H12 V3 L8 6.5 L12 10 V12.5 H1 V10 L5 6.5 L1 3 Z" fill="#ffff80" stroke="#000"/><path d="M4 11 H9 L6.5 8.5 Z" fill="#c0a000"/></g>';
    if (tone === "danger")
        return open + '<circle cx="6.5" cy="6.5" r="6" fill="#ff0000" stroke="#800000"/><path d="M4 4 L9 9 M9 4 L4 9" stroke="#fff" stroke-width="1.8"/></g>';
    if (tone === "warning")
        return open + '<path d="M6.5 0.5 L12.5 12.5 H0.5 Z" fill="#ffff00" stroke="#000" stroke-width="1" stroke-linejoin="round"/><rect x="6" y="4" width="1.4" height="5" fill="#000"/><rect x="6" y="10" width="1.4" height="1.4" fill="#000"/></g>';
    return "";
}

function svg(status, tone, size, selected, colors) {
    var s = size >= 32 ? 32 : 16;
    var g = shade(grid(status, s), tone === "muted", !!selected, (colors && colors.selection) || "#000080");
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + s + '" height="' + s + '" viewBox="0 0 ' + s + ' ' + s + '">'
        + '<g shape-rendering="crispEdges">' + runs(g) + '</g>' + overlay(status, tone, s) + '</svg>';
}

// The fleet's own icon (the tray, the captions, a minimized Fleet's
// taskbar button): the fleet as one host. fleet: beszel-model.js fleetView.
function fleetLook(fleet, stale) {
    var status = fleet.state === "loading" ? "pending" : fleet.state === "ready" ? "up" : "down";
    var tone = fleet.state !== "ready" || stale || fleet.hosts.length === 0 ? "muted" : fleet.tone;
    return {status: status, tone: tone};
}
