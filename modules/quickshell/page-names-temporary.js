.pragma library
// TEMPORARY. A stand-in for pages-caption's page-names.js (not landed when
// this branch was written), written from its agreed wording. When
// page-names.js lands, import it instead and delete this file; the parent
// reconciles the two on landing.
//
// Pages are never numbered on screen; a page is named by the apps on it.
// names: app names in left-to-right order (repeats are dropped).
//   listNames: "Signal" / "Signal and Zed" / "Signal, Zed and Ghostty" /
//              "Signal, Zed, Ghostty…"
//   pageLabel: the same after "Beside "; "" for no names.

function unique(names) {
    var out = [];
    for (var i = 0; i < (names || []).length; i++) {
        var n = String(names[i] || "");
        if (n !== "" && out.indexOf(n) < 0) out.push(n);
    }
    return out;
}

function listNames(names) {
    var u = unique(names);
    if (u.length === 0) return "";
    if (u.length === 1) return u[0];
    if (u.length === 2) return u[0] + " and " + u[1];
    if (u.length === 3) return u[0] + ", " + u[1] + " and " + u[2];
    return u[0] + ", " + u[1] + ", " + u[2] + "\u2026";
}

function pageLabel(names) {
    var l = listNames(names);
    return l === "" ? "" : "Beside " + l;
}
