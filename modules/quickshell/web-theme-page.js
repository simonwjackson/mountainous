// The in-page half of WebTheme.qml. web-theme.js wraps this function
// expression as `(fn)(payload);` and Chromium runs it in every frame before
// the page's own scripts, and again on every theme change.
//
// It keeps one constructed stylesheet per section on the window and only
// replaces their text. Constructed sheets are CSSOM, so a strict style-src
// policy does not block them, and the page's DOM is never edited.
(function (payload) {
    "use strict";
    var key = Symbol.for("mountainous.webTheme");
    if (typeof CSSStyleSheet !== "function" || !document || !("adoptedStyleSheets" in document)) return;
    var state = window[key];
    if (!state) {
        state = { sheets: [], byName: {}, applied: 0, first: 0, appearance: "", theme: "", host: "", off: [] };
        state.adopt = function () {
            try {
                var current = document.adoptedStyleSheets;
                var missing = state.sheets.filter(function (s) { return current.indexOf(s) < 0; });
                if (missing.length) document.adoptedStyleSheets = current.concat(missing);
            } catch (e) { /* a document that cannot adopt sheets keeps its own look */ }
        };
        Object.defineProperty(window, key, { value: state });
        // A page that assigns adoptedStyleSheets wholesale drops ours; take
        // them back once the document settles.
        document.addEventListener("DOMContentLoaded", state.adopt);
        window.addEventListener("load", state.adopt);
    }

    var host = location.hostname;
    if (!host && location.ancestorOrigins && location.ancestorOrigins.length) {
        try { host = new URL(location.ancestorOrigins[0]).hostname; } catch (e) { host = ""; }
    }
    var rule = null;
    var sites = payload.sites || {};
    for (var h = host; h && !rule; h = h.indexOf(".") > 0 ? h.slice(h.indexOf(".") + 1) : "") {
        if (Object.prototype.hasOwnProperty.call(sites, h)) rule = sites[h];
    }
    var off = (rule && rule.off) || [];
    var skip = (rule && rule.skip) || "";

    var sections = [["tokens", payload.tokens || ""]];
    (payload.order || []).forEach(function (name) {
        var text = off.indexOf(name) >= 0 ? "" : (payload.levels[name] || "");
        if (skip && name === "forms") text = text.split("[data-mtn-skip]").join("[data-mtn-skip], " + skip);
        sections.push([name, text]);
    });
    sections.forEach(function (pair) {
        var sheet = state.byName[pair[0]];
        if (!sheet) {
            sheet = new CSSStyleSheet();
            state.byName[pair[0]] = sheet;
            state.sheets.push(sheet);
        }
        try { sheet.replaceSync(pair[1]); } catch (e) { sheet.replaceSync(""); }
    });
    state.adopt();
    state.applied = Date.now();
    if (!state.first) state.first = state.applied;
    state.appearance = payload.appearance || "";
    state.theme = payload.theme || "";
    state.host = host;
    state.off = off;
})
