.pragma library
// The StatusNotifierItem host's rules, for both themes (SniTray.qml owns
// the items; the Memphis tray row and the Platinum top bar's status area
// draw them after their built-in controls). Pure, so sni-tray.test.js
// runs it under node.
//
// An item as SniTray.qml hands it over (plain values):
//   { id, title, status: "Passive" | "Active" | "NeedsAttention",
//     iconSource (Quickshell's icon URL), tooltipTitle, tooltipDescription,
//     hasMenu, onlyMenu }

// Stable keys: "sni:<id>", and "sni:<id>#2" for a second item with the
// same id (two instances of one app). The bars and the plans use the key.
var PREFIX = "sni:";
function isKey(k) { return typeof k === "string" && k.indexOf(PREFIX) === 0; }

function safeId(id) { return String(id || "item").replace(/[^A-Za-z0-9._-]/g, "_") || "item"; }

// The icon-theme name inside Quickshell's icon URL
// ("image://icon/<name>?fallback=…&theme=…"), or "" for a pixmap or a
// file (an app's own picture).
function iconName(source) {
    var s = String(source || "");
    var m = /^image:\/\/icon\/([^?&]+)/.exec(s);
    if (!m) return "";
    try { return decodeURIComponent(m[1]); } catch (e) { return m[1]; }
}

// What the bar draws, in registration order: Passive items hide (the
// app says nothing needs showing), every other item shows. Order never
// changes with status, so an icon does not jump when it starts to blink.
function rows(items) {
    var seen = {}, out = [];
    for (var i = 0; i < (items || []).length; i++) {
        var it = items[i];
        if (!it || it.status === "Passive") continue;
        var base = PREFIX + safeId(it.id);
        seen[base] = (seen[base] || 0) + 1;
        out.push({
            key: seen[base] > 1 ? base + "#" + seen[base] : base,
            index: i,
            id: String(it.id || ""),
            label: label(it),
            tooltip: tooltip(it),
            iconSource: String(it.iconSource || ""),
            iconName: iconName(it.iconSource),
            attention: it.status === "NeedsAttention",
            hasMenu: !!it.hasMenu,
            onlyMenu: !!it.onlyMenu && !!it.hasMenu
        });
    }
    return out;
}

function strip(s) { return String(s || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").trim(); }

// The name a menu or the overflow lists: the tooltip's title, the item's
// title, its id.
function label(it) { return strip(it.tooltipTitle) || strip(it.title) || String(it.id || "Application"); }
function tooltip(it) {
    var head = label(it), body = strip(it.tooltipDescription);
    return body && body !== head ? head + "\n" + body : head;
}

// What a press does: "activate", "secondary", "menu" or "none".
// Left activates (an item that is only a menu opens it); middle is the
// secondary activation; right opens the app's menu, or activates an item
// that has none (as Windows and KDE hosts do).
function press(row, button) {
    if (!row) return "none";
    if (button === "middle") return "secondary";
    if (button === "right") return row.hasMenu ? "menu" : "activate";
    return row.onlyMenu ? "menu" : "activate";
}

// What choosing an item in an overflow menu does: open its menu when it
// has one (the menu then starts with its default command), else activate.
function overflowChoice(row) {
    if (!row) return "none";
    return row.hasMenu ? "menu" : "activate";
}

// A dbusmenu label: "_" marks the access key, "__" is a literal "_".
// Memphis marks with "&" ("&&" literal); Platinum has none.
function accessText(text) {
    var s = String(text || "").replace(/&/g, "&&"), out = "";
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i);
        if (c === "_") {
            if (s.charAt(i + 1) === "_") { out += "_"; i++; }
            else if (i + 1 < s.length) out += "&";
        } else out += c;
    }
    return out;
}
function plainText(text) {
    var s = String(text || ""), out = "";
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i);
        if (c === "_") { if (s.charAt(i + 1) === "_") { out += "_"; i++; } }
        else out += c;
    }
    return out;
}

// A loaded dbusmenu level (SniMenuTree.qml): [{ text, enabled, separator,
// check: "none" | "checkbox" | "radio", checked, children: [...], ref }].
// Leading, trailing and doubled separators go; empty submenus stay
// (disabled) so the item is still seen.
function tidy(entries) {
    var out = [];
    for (var i = 0; i < (entries || []).length; i++) {
        var e = entries[i];
        if (!e) continue;
        if (e.separator) {
            if (out.length && !out[out.length - 1].separator) out.push(e);
            continue;
        }
        out.push(e);
    }
    while (out.length && out[out.length - 1].separator) out.pop();
    return out;
}
