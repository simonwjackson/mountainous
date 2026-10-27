.pragma library
// Pages without numbers. Simon: "I don't ever want to see the number of a
// workspace." A page is named by the apps on it, in both themes:
//
//   listNames  "Signal", "Signal and Zed", "Signal, Zed and Ghostty",
//              "Signal, Zed, Ghostty…"   (a divider's tooltip or label)
//   beside     "Beside Signal and Zed"   (a Move to page row)
//   moveBeside "Move beside Signal and Zed" (a drag onto another page)
//
// Page ids stay internal: they order the pages along the strip and go to
// the compositor, and they are never in a returned label. Platinum's strip
// and tile menu and the Win98 taskbar and Move to Page menu share this file,
// so the two themes keep the same words. node page-names.test.js runs it.

// At most this many names; a longer list ends with "…".
var MAX_NAMES = 3;

// The names once each, in their first order, without blanks.
function unique(names) {
    var out = [], seen = {};
    for (var i = 0; i < (names || []).length; i++) {
        var n = String(names[i] === undefined || names[i] === null ? "" : names[i]).trim();
        if (n === "" || seen[n]) continue;
        seen[n] = true;
        out.push(n);
    }
    return out;
}

// The apps on a page as text, "" for none.
function listNames(names) {
    var n = unique(names);
    if (n.length === 0) return "";
    if (n.length === 1) return n[0];
    if (n.length <= MAX_NAMES) return n.slice(0, -1).join(", ") + " and " + n[n.length - 1];
    return n.slice(0, MAX_NAMES).join(", ") + "…";
}

function beside(names) {
    var l = listNames(names);
    return l === "" ? "" : "Beside " + l;
}

function moveBeside(names) {
    var l = listNames(names);
    return l === "" ? "Move to an empty page" : "Move beside " + l;
}

// The names on one page, in strip order, leaving out the window `self`
// (an address) when given. windows: [{ page, name, address }].
function namesOn(windows, page, self) {
    var out = [];
    for (var i = 0; i < (windows || []).length; i++) {
        var w = windows[i];
        if (w && w.page === page && !(self && w.address === self)) out.push(w.name);
    }
    return unique(out);
}

// The Move to page ▸ rows for one window.
//   windows   one screen's windows in strip order: [{ page, name, address }]
//   self      the moving window's address
//   ownPage   the page it is on (checked and disabled)
//   shownPage the page the screen shows (listed even when empty)
//   pageIds   every page id on every screen (Hyprland numbers pages
//             globally, so a new page is numbered after all of them)
// Returns { pages: [{ page, label, current }], newPage }. Labels:
// "Beside Signal and Zed"; the own page alone reads "On its own"; an empty
// page that is not the own page reads "Empty page". Then "New page".
var NEW_PAGE = "New page";
function movePages(windows, self, ownPage, shownPage, pageIds) {
    var seen = {}, pages = [];
    function add(p) { if (p > 0 && !seen[p]) { seen[p] = true; pages.push(p); } }
    for (var i = 0; i < (windows || []).length; i++) add(windows[i] && windows[i].page);
    add(shownPage);
    add(ownPage);
    pages.sort(function (a, b) { return a - b; });
    var top = 0;
    for (var j = 0; j < (pageIds || []).length; j++) if (pageIds[j] > top) top = pageIds[j];
    for (var k = 0; k < pages.length; k++) if (pages[k] > top) top = pages[k];
    return {
        pages: pages.map(function (p) {
            var current = p === ownPage;
            var names = namesOn(windows, p, self);
            return { page: p, current: current,
                     label: names.length ? beside(names) : current ? "On its own" : "Empty page" };
        }),
        newPage: top + 1
    };
}
