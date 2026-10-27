.pragma library
// The Find menu's rows and the omni service's entry rules. Plain functions
// over plain rows, so they run under node (find-model.test.js) and in QML.
//
// The omni service (OmniBar.qml) owns the data: windowRows, appRows,
// commandRows, and Launcher.recent. A theme's view turns them into the rows
// below and runs a chosen row back through the service. The service's own
// unthemed card keeps today's flat list and does not use findRows.
//
// A row: { t: "head" | "sep" | "item",
//          k: "win" | "app" | "recent" | "cmd" | "scope" | "addr" | "none",
//          label, hint, icon, dis, to (scope id), ref (the service row),
//          entry (a Launcher.recent entry), kind ("app" | "webapp") }

// The scopes, in the pop-up's order, with the mode the service calls them by.
var SCOPES = [
    { id: "all", mode: "root", label: "All", key: "" },
    { id: "app", mode: "app", label: "Applications", key: "Ctrl+1" },
    { id: "win", mode: "window", label: "Windows", key: "Ctrl+2" },
    { id: "cmd", mode: "cmd", label: "Commands", key: "Ctrl+3" }
];

function scopeOf(mode) {
    for (var i = 0; i < SCOPES.length; i++) if (SCOPES[i].mode === mode) return SCOPES[i].id;
    return "all";
}
function modeOf(scope) {
    for (var i = 0; i < SCOPES.length; i++) if (SCOPES[i].id === scope) return SCOPES[i].mode;
    return "root";
}
function scopeLabel(scope) {
    for (var i = 0; i < SCOPES.length; i++) if (SCOPES[i].id === scope) return SCOPES[i].label;
    return SCOPES[0].label;
}

// ------------------------------------------------------------------ entry
// The service's state is { shown, mode, query, caller }. Every way in (Super+P,
// F1, Super+Shift+P, Ctrl+L, Apple menu ▸ Find…, Win98 Run…, the IPC targets)
// goes through enter(). The caller is the window that had focus when the
// menu was summoned; "Go to Address" acts on it. It is captured on the way
// in, before the menu takes the keyboard, and kept while the menu moves
// between scopes and the dialog, so a later step never sees a stale window.
function enter(state, mode, active, query) {
    var s = state || {};
    return {
        shown: true,
        mode: mode || "root",
        query: typeof query === "string" ? query : "",
        caller: s.shown ? (s.caller || null) : (active || null)
    };
}

// Esc: leave the scope, else close. The caller goes with the menu.
function back(state) {
    var s = state || {};
    if (s.shown && s.mode && s.mode !== "root") return { shown: true, mode: "root", query: "", caller: s.caller || null };
    return close(s);
}
function close(state) {
    return { shown: false, mode: "root", query: "", caller: null };
}

// ------------------------------------------------------------------ kinds
// A desktop entry named webapp-<id> is a declared web app (modules/web-apps.nix).
// Launcher records it as "webapp", as the Apple menu does.
function launchKind(id) {
    return typeof id === "string" && id.indexOf("webapp-") === 0 ? "webapp" : "app";
}

// ------------------------------------------------------------------ ranking
// Today's match (OmniBar.matches): a case-insensitive substring of the name,
// the detail or the id. New: a rank, so a name that starts with the text
// comes first (type-selection order), then a word start, then the rest of
// the name, then the detail, the id and the generic name.
function rank(row, q) {
    if (!q) return 0;
    var n = String(q).toLowerCase(), l = String(row.label || "").toLowerCase();
    if (l.indexOf(n) === 0) return 0;
    var words = l.split(/[\s\-–—·\/_.(:,]+/);
    for (var i = 0; i < words.length; i++) if (words[i] !== "" && words[i].indexOf(n) === 0) return 1;
    if (l.indexOf(n) >= 0) return 2;
    var more = [row.hint, row.id, row.generic, row.match];
    for (var j = 0; j < more.length; j++)
        if (more[j] && String(more[j]).toLowerCase().indexOf(n) >= 0) return 3;
    return -1;
}
// Matching rows, best rank first, the original order inside a rank.
function filter(rows, q) {
    if (!q) return rows.slice();
    var scored = [];
    for (var i = 0; i < rows.length; i++) {
        var k = rank(rows[i], q);
        if (k >= 0) scored.push({ r: rows[i], i: i, k: k });
    }
    scored.sort(function (a, b) { return a.k - b.k || a.i - b.i; });
    return scored.map(function (x) { return x.r; });
}

// ------------------------------------------------------------------ items
function head(label) { return { t: "head", label: label }; }
function sep() { return { t: "sep" }; }

// ctx.windows come from OmniBar.windowRows: the front window already left
// out, the focused screen first, most recent first inside a screen.
// { label, page, shown, screen, order, appId, icon, ref }
// A row never shows a page number (docs/plans/desktop-themes.md, "No
// workspace numbers"): the hint names the other screen, else is empty.
// page and shown stay on the row, unrendered, to group it.
function windowItems(ctx) {
    var here = ctx.here || "";
    var label = ctx.screenLabel || function (s) { return s; };
    return (ctx.windows || []).map(function (w) {
        var other = w.screen && here && w.screen !== here;
        return {
            t: "item", k: "win", label: w.label || "(untitled)", icon: w.icon || "",
            hint: other ? label(w.screen) : "",
            id: w.appId || "", screen: w.screen || "", page: w.page > 0 ? w.page : 0, shown: !!w.shown, ref: w.ref
        };
    });
}
// One screen's rows, page by page: the page the screen shows first, then
// the other pages, each where its most recent window falls, with a rule
// between pages. Inside a page the rows keep their order.
function byPage(items) {
    var pages = [], groups = {};
    for (var i = 0; i < items.length; i++) {
        var p = items[i].page;
        if (!groups[p]) { groups[p] = []; pages.push(p); }
        groups[p].push(items[i]);
    }
    var first = -1;
    for (var j = 0; j < items.length; j++) if (items[j].shown) { first = items[j].page; break; }
    if (first >= 0) pages.sort(function (a, b) { return (a === first ? 0 : 1) - (b === first ? 0 : 1); });
    var out = [];
    for (var k = 0; k < pages.length; k++) {
        if (k > 0) out.push(sep());
        out = out.concat(groups[pages[k]]);
    }
    return out;
}
// Window rows under one heading per screen when they sit on more than one,
// else under one "Windows" heading (headed: false leaves it out). paged
// splits each screen's rows by page (an untouched field); a filtered list
// keeps its rank order instead.
function windowGroups(items, ctx, headed, paged) {
    var label = ctx.screenLabel || function (s) { return s; };
    var screens = [], of = {};
    for (var i = 0; i < items.length; i++) {
        var s = items[i].screen;
        if (!of[s]) { of[s] = []; screens.push(s); }
        of[s].push(items[i]);
    }
    var arrange = paged ? byPage : function (rows) { return rows; };
    var out = [];
    if (screens.length < 2) {
        if (headed && items.length) out.push(head("Windows"));
        return out.concat(arrange(items));
    }
    for (var j = 0; j < screens.length; j++) {
        out.push(head("Windows on " + label(screens[j])));
        out = out.concat(arrange(of[screens[j]]));
    }
    return out;
}
// ctx.apps come from OmniBar.appRows: { label, id, generic, icon, ref }.
function appItems(ctx) {
    return (ctx.apps || []).map(function (a) {
        var kind = launchKind(a.id);
        return { t: "item", k: "app", label: a.label, icon: a.icon || "", id: a.id || "", generic: a.generic || "",
                 hint: kind === "webapp" ? "web app" : "", kind: kind, ref: a.ref };
    });
}
// The five most recent launches, from Launcher.recent.
var RECENT_COUNT = 5;
function recentItems(ctx) {
    return (ctx.recent || []).filter(function (r) { return r && (r.name || r.id); }).slice(0, RECENT_COUNT).map(function (r) {
        return { t: "item", k: "recent", label: r.name || r.id, icon: r.icon || "", id: r.id || "",
                 hint: r.kind === "webapp" ? "web app" : "", kind: r.kind === "webapp" ? "webapp" : "app", entry: r };
    });
}
// ctx.commands come from OmniBar.commandRows: { label, detail, act }.
function commandItems(ctx) {
    return (ctx.commands || []).map(function (c) {
        return { t: "item", k: "cmd", label: c.label, hint: c.detail || "", act: c.act, ref: c };
    });
}

// A text that reads as a host or a URL ("nixos.org", "https://…").
function looksLikeAddress(q) {
    return /^[^\s\/]+\.[^\s\/]{2,}/.test(q) || /^[a-z][a-z0-9+.-]*:\/\//i.test(q);
}
// What CdpBrowser.navigate does with a text: a URL stays, a host gets
// https://, anything else is a DuckDuckGo search.
function isBareWords(q) {
    var t = String(q || "").trim();
    return t !== "" && !/^[a-z][a-z0-9+.-]*:/i.test(t) && !/^[^\s\/]+\.[^\s\/]+/.test(t);
}

// ------------------------------------------------------------------ rows
// The Find menu's rows for a scope and a query.
function findRows(scope, q, ctx) {
    var c = ctx || {};
    var query = String(q || "");
    var wins = windowItems(c), apps = appItems(c), recent = recentItems(c), cmds = commandItems(c);
    var out = [];
    function section(title, rows) { if (rows.length) { out.push(head(title)); for (var i = 0; i < rows.length; i++) out.push(rows[i]); } }
    function push(rows) { for (var i = 0; i < rows.length; i++) out.push(rows[i]); }

    if (scope === "all" && !query) {
        // An untouched field leads with the windows behind the front one, so
        // Return goes back to the last window.
        push(windowGroups(wins, c, true, true));
        section("Recent Applications", recent);
        section("Commands", cmds);
        if (apps.length)
            out.push(sep(), { t: "item", k: "scope", to: "app", label: "All Applications…",
                              hint: apps.length + (apps.length === 1 ? " item" : " items") + "  Ctrl+1" });
    } else if (scope === "all") {
        // As today: applications and commands first, matching windows under them.
        section("Applications", filter(apps, query));
        section("Commands", filter(cmds, query));
        push(windowGroups(filter(wins, query), c, true));
    } else if (scope === "app") {
        if (!query) { section("Recent Applications", recent); section("All Applications", apps); }
        else push(filter(apps, query));
    } else if (scope === "win") {
        push(windowGroups(query ? filter(wins, query) : wins, c, false, !query));
    } else if (scope === "cmd") {
        push(filter(cmds, query));
    }

    if (query && looksLikeAddress(query)) {
        // Under the other matches; alone, with no rule above it.
        if (out.length) out.push(sep());
        out.push({ t: "item", k: "addr", label: "Go to “" + query + "”", hint: "Ctrl+L", text: query });
    }

    if (!out.some(function (r) { return r.t === "item"; })) {
        if (scope === "win" && !query) out.push({ t: "item", k: "none", dis: true, label: "No other windows" });
        else if (scope === "cmd" && !query) out.push({ t: "item", k: "none", dis: true, label: "No commands" });
        else if (scope === "app" && !query) out.push({ t: "item", k: "none", dis: true, label: "No applications" });
        else if (scope === "all" && !query) out.push({ t: "item", k: "none", dis: true, label: "Nothing to show" });
        else {
            out.push({ t: "item", k: "none", dis: true,
                       label: "Nothing named “" + query + "”" + (scope === "all" ? "" : " in " + scopeLabel(scope)) });
            if (scope !== "all") out.push({ t: "item", k: "scope", to: "all", label: "Search All for “" + query + "”", hint: "Esc", keep: true });
            out.push({ t: "item", k: "addr", label: "Go to Address “" + query + "”…", hint: "Ctrl+L", text: query });
        }
    }
    return out;
}

// ------------------------------------------------------------------ selection
function selectable(r) { return !!r && r.t === "item" && !r.dis; }
function firstSelectable(rows) {
    for (var i = 0; i < rows.length; i++) if (selectable(rows[i])) return i;
    return -1;
}
// The next selectable row from `from` in `dir`, wrapping, as today's list did.
function step(rows, from, dir) {
    var n = rows.length;
    if (!n) return -1;
    for (var k = 1; k <= n; k++) {
        var i = ((from + dir * k) % n + n) % n;
        if (selectable(rows[i])) return i;
    }
    return -1;
}
// PageUp / PageDown: `count` selectable rows on, stopping at the ends.
function page(rows, from, dir, count) {
    var at = from, moved = 0;
    for (var i = from + dir; i >= 0 && i < rows.length && moved < count; i += dir) {
        if (selectable(rows[i])) { at = i; moved++; }
    }
    if (at === from && from < 0) return firstSelectable(rows);
    return at;
}

// ------------------------------------------------------------------ geometry
// Row heights in logical px: items 24, group labels 20, separators 9.
var ROW = 24, HEAD = 20, SEP = 9;
function rowHeight(r) { return !r ? 0 : r.t === "head" ? HEAD : r.t === "sep" ? SEP : ROW; }
function rowTop(rows, index) {
    var y = 0;
    for (var i = 0; i < index && i < rows.length; i++) y += rowHeight(rows[i]);
    return y;
}
function contentHeight(rows) { return rowTop(rows, rows.length); }
// The scroll offset that keeps row `index` whole inside a view `view` px
// tall, with `band` px of scroll arrow covering a cut edge.
function scrollFor(rows, index, scroll, view, band) {
    var total = contentHeight(rows);
    var max = Math.max(0, total - view);
    if (index < 0 || total <= view) return 0;
    var top = rowTop(rows, index), bottom = top + rowHeight(rows[index]);
    var s = Math.max(0, Math.min(scroll, max));
    // Room under the arrow bands that show at this offset.
    if (top < s + (s > 0 ? band : 0)) s = Math.max(0, top - band);
    if (bottom > s + view - (s < max ? band : 0)) s = Math.min(max, bottom - view + band);
    // The first selectable row of a list starts at the top, unscrolled.
    if (index === firstSelectable(rows) && top < view - band) s = 0;
    return Math.max(0, Math.min(s, max));
}

// ------------------------------------------------------------------ Go to Address
// The open pages the dialog lists: all of them while the field still holds
// the current URL or nothing, else those whose URL or title contain the text.
function addressPages(pages, text, base) {
    var t = String(text || "").trim().toLowerCase();
    if (t === "" || (base && t === String(base).toLowerCase())) return (pages || []).slice();
    return (pages || []).filter(function (p) {
        return String(p.url || "").toLowerCase().indexOf(t) >= 0 || String(p.title || "").toLowerCase().indexOf(t) >= 0;
    });
}
// What the dialog says about where Go opens. target: the caller's CDP page
// (CdpBrowser.targetFor) or null; caller: { title, appName } or null.
function destination(caller, target) {
    if (caller && target) return { here: true, text: "Opens in this window:", title: caller.title || target.title || "" };
    var why = caller && caller.appName ? " (" + caller.appName + " has no address)" : "";
    return { here: false, text: "Opens in a new window" + why, title: "" };
}
