.pragma library
// Running apps for every theme: windows grouped by app, the most recently
// used order, and the order Super+Tab cycles in. Plain functions over plain
// rows (see window-hide.js for the row shape), so they run under node.
//
// An app is a window class (Wayland app id). Electron apps that report one
// shared class merge into one app; two browser profiles split one site into
// two apps. Hyprland gives no better grouping.

function key(address) {
    return String(address || "").replace(/^0x/, "");
}

// Most recently used first. `mru` is a list of window keys.
function touch(mru, address) {
    var k = key(address);
    if (k === "") return (mru || []).slice();
    var out = [k];
    for (var i = 0; i < (mru || []).length && out.length < 256; i++)
        if (mru[i] !== k) out.push(mru[i]);
    return out;
}

// Keep only windows that still exist, and add unknown ones at the end in
// Hyprland's focus history order (focusHistoryID: 0 is the most recent).
function reconcile(mru, rows) {
    var live = {}, out = [];
    for (var i = 0; i < (rows || []).length; i++) live[key(rows[i].address)] = rows[i];
    for (var j = 0; j < (mru || []).length; j++) if (live[mru[j]] && out.indexOf(mru[j]) < 0) out.push(mru[j]);
    var rest = (rows || []).filter(function (r) { return out.indexOf(key(r.address)) < 0 && key(r.address) !== ""; });
    rest.sort(function (a, b) {
        var fa = typeof a.focusHistory === "number" && a.focusHistory >= 0 ? a.focusHistory : 1e9;
        var fb = typeof b.focusHistory === "number" && b.focusHistory >= 0 ? b.focusHistory : 1e9;
        return fa - fb;
    });
    for (var k = 0; k < rest.length; k++) out.push(key(rest[k].address));
    return out;
}

function rank(mru, address) {
    var i = (mru || []).indexOf(key(address));
    return i < 0 ? 1e9 : i;
}

function hiddenRow(r) {
    return !!r && typeof r.workspace === "string" && r.workspace.indexOf("special:hidden-") === 0;
}

// One entry per app, sorted by name as Mac OS 8.5 sorted the Application
// menu. names maps app id -> display name; icons maps app id -> icon name.
// Each app's windows are most recent first.
function apps(rows, mru, front, names, icons) {
    var by = {}, order = [];
    var frontKey = key(front);
    for (var i = 0; i < (rows || []).length; i++) {
        var r = rows[i];
        if (!r || !r.appId) continue;
        if (!by[r.appId]) { by[r.appId] = []; order.push(r.appId); }
        by[r.appId].push(r);
    }
    var out = order.map(function (id) {
        var windows = by[id].slice().sort(function (a, b) {
            return rank(mru, a.address) - rank(mru, b.address) || (a.page - b.page);
        });
        var hiddenCount = windows.filter(hiddenRow).length;
        return {
            appId: id,
            name: (names && names[id]) || id,
            icon: (icons && icons[id]) || id,
            windows: windows,
            count: windows.length,
            hidden: hiddenCount === windows.length,
            hiddenCount: hiddenCount,
            front: windows.some(function (w) { return key(w.address) === frontKey && frontKey !== ""; }),
        };
    });
    out.sort(function (a, b) {
        var x = a.name.toLowerCase(), y = b.name.toLowerCase();
        return x < y ? -1 : x > y ? 1 : (a.appId < b.appId ? -1 : a.appId > b.appId ? 1 : 0);
    });
    return out;
}

// App ids in most recently used order: an app ranks by its most recent
// window. Apps none of whose windows are in mru follow, by name.
function appOrder(rows, mru, names) {
    var best = {}, ids = [];
    for (var i = 0; i < (rows || []).length; i++) {
        var r = rows[i];
        if (!r || !r.appId) continue;
        var k = rank(mru, r.address);
        if (!(r.appId in best)) { best[r.appId] = k; ids.push(r.appId); }
        else best[r.appId] = Math.min(best[r.appId], k);
    }
    ids.sort(function (a, b) {
        if (best[a] !== best[b]) return best[a] - best[b];
        var x = ((names && names[a]) || a).toLowerCase(), y = ((names && names[b]) || b).toLowerCase();
        return x < y ? -1 : x > y ? 1 : 0;
    });
    return ids;
}

// The app's most recent window, shown windows before hidden ones only when
// they rank equal (a hidden window is still a valid target: choosing it
// shows the app first).
function recentWindow(app, mru) {
    if (!app || !app.windows || app.windows.length === 0) return null;
    var list = app.windows.slice().sort(function (a, b) { return rank(mru, a.address) - rank(mru, b.address); });
    return list[0];
}

// ---------------------------------------------------------------- Super+Tab
// A quick Super+Tab is Hyprland's "focus last window" (hyprland.lua). When
// Super stays down and Tab comes again, hyprland.lua sends positions 2, 3, …
// (each Shift+Tab one less) and a commit with the final position. By then
// the first press has already swapped the two most recent windows, so the
// order the user started from is the current MRU with its first two
// entries swapped back.
//
// The cycle walks apps in that order, starting after the app now in front,
// so position 2 is the next app after the one the quick press reached.
function cycleStart(rows, mru, names) {
    var before = (mru || []).slice();
    if (before.length >= 2) { var t = before[0]; before[0] = before[1]; before[1] = t; }
    var order = appOrder(rows, before, names);
    var frontRow = null;
    for (var i = 0; i < (rows || []).length; i++)
        if (mru && mru.length > 0 && key(rows[i].address) === mru[0]) frontRow = rows[i];
    var base = frontRow ? order.indexOf(frontRow.appId) : 0;
    return { order: order, base: base < 0 ? 0 : base };
}

// The same cycle over windows, not apps (Win98's Cool Switch, as Alt+Tab
// stepped through windows): every live window in the order before the
// quick press, hidden ones included, starting from the window the quick
// press reached. order holds window keys; cycleTarget reads it alike.
function windowCycleStart(rows, mru) {
    var live = {}, liveOrder = [];
    for (var i = 0; i < (rows || []).length; i++) {
        var k = key(rows[i].address);
        if (k !== "" && !live[k]) { live[k] = true; liveOrder.push(k); }
    }
    var before = [];
    for (var j = 0; j < (mru || []).length; j++) {
        var m = key(mru[j]);
        if (live[m] && before.indexOf(m) < 0) before.push(m);
    }
    // Windows the MRU does not know yet follow, in Hyprland's order.
    for (var n = 0; n < liveOrder.length; n++) if (before.indexOf(liveOrder[n]) < 0) before.push(liveOrder[n]);
    var front = mru && mru.length > 0 ? key(mru[0]) : "";
    if (before.length >= 2 && before[0] === front) { var t = before[0]; before[0] = before[1]; before[1] = t; }
    var base = before.indexOf(front);
    return { order: before, base: base < 0 ? 0 : base };
}

// The target app for a position (1 = the app the quick press reached).
function cycleTarget(cycle, position) {
    if (!cycle || !cycle.order || cycle.order.length === 0) return "";
    var n = cycle.order.length;
    var i = ((cycle.base + position - 1) % n + n) % n;
    return cycle.order[i];
}

// hyprland.lua numbers every cycle message. A message older than the last
// one handled is stale (two qs processes can arrive out of order), and the
// commit carries the final position, so a late step cannot undo it.
function accept(lastSeq, seq) {
    return typeof seq === "number" && seq > lastSeq;
}
