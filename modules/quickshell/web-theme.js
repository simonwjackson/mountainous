.pragma library

// Theme-to-stylesheet policy for WebTheme.qml. Pure: no QML, no I/O, so
// web-theme.test.js runs the same file under node.
//
// A theme opts in to web styling with one file, themes/<id>/web.css. The
// file is cut at its section markers:
//   /* @tokens all */      always applied, first
//   /* @tokens <mode> */   one per appearance: light, dark, and optionally
//                          extra (used only while Extra dark is on)
//   /* @level <name> */    type, scrollbars, forms; a site may switch a
//                          level off (see sites below)
// A theme without web.css restyles nothing: every sheet becomes empty, so
// switching to it also clears the previous theme from open pages.

var levels = ["type", "scrollbars", "forms"];

// Per-site opt-outs. Matched against the frame's host and each parent
// domain. `off` lists levels to skip; `skip` is a selector list that the
// in-page script adds to every guard in the forms level. Every entry
// records what broke, so it can be retested and removed.
var sites = {
    "music.youtube.com": {
        skip: "ytmusic-search-box input",
        why: "The search box draws its own field around the input, with icon buttons beside it; a Platinum well inside it read as a field within a field (2026-10-23)."
    }
};

function cssPath(themeName) {
    return /^[a-z][a-z0-9-]*$/.test(themeName || "") ? "themes/" + themeName + "/web.css" : "";
}

// Split web.css into its sections. Text before the first marker is a
// comment for people and is dropped.
function parse(cssText) {
    var out = { tokens: {}, levels: {} };
    var marker = /\/\*\s*@(tokens|level)\s+([a-z-]+)\s*\*\//g;
    var text = cssText || "";
    var found = [];
    var m;
    while ((m = marker.exec(text)) !== null) found.push({ kind: m[1], name: m[2], start: m.index, body: marker.lastIndex });
    for (var i = 0; i < found.length; i++) {
        var end = i + 1 < found.length ? found[i + 1].start : text.length;
        var body = text.slice(found[i].body, end).trim();
        var bucket = found[i].kind === "tokens" ? out.tokens : out.levels;
        bucket[found[i].name] = (bucket[found[i].name] ? bucket[found[i].name] + "\n" : "") + body;
    }
    return out;
}

// Which token block applies. Extra dark only blackens the desktop bar, so
// page controls use dark unless a theme ships its own "extra" block.
function appearance(sections, mode, extraDark) {
    var dark = mode !== "light";
    if (dark && extraDark && sections.tokens.extra) return "extra";
    return dark ? "dark" : "light";
}

function payload(cssText, themeName, mode, extraDark) {
    var sections = parse(cssText);
    var key = appearance(sections, mode, extraDark);
    var enabled = !!(sections.tokens[key] || "") && levels.some(function (l) { return !!sections.levels[l]; });
    var sheetLevels = {};
    for (var i = 0; i < levels.length; i++) sheetLevels[levels[i]] = enabled ? (sections.levels[levels[i]] || "") : "";
    return {
        v: 1,
        theme: themeName || "",
        appearance: enabled ? key : "",
        tokens: enabled ? [sections.tokens.all || "", sections.tokens[key]].join("\n") : "",
        levels: sheetLevels,
        order: levels,
        sites: sites
    };
}

// The source Chromium evaluates in each frame: the in-page function from
// web-theme-page.js, called with the payload.
function script(pageText, data) {
    return "(" + String(pageText).trim().replace(/;\s*$/, "") + ")(" + JSON.stringify(data) + ");";
}
