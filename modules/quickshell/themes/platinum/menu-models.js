.pragma library
// The rows of the Platinum menus that are built from data: the Apple menu
// under the mountain, the Application menu at the right end of the bar,
// and a Control Strip tile's menu. PlatinumCascadeMenu draws any list of
// these rows, with cascades.
//
// A row: { kind: "item" | "separator" | "header",
//          id, label, detail, hint, count,
//          icon (a Platinum mark in icons/), app (an app icon name),
//          spacer (keep the icon column empty), check, disabled, dim,
//          submenu: [rows], action: { … } }

function sep() { return { kind: "separator" }; }

function item(o) {
    var out = { kind: "item" };
    for (var k in o) out[k] = o[k];
    return out;
}

// Control Panels ▸: each opens that control's own menu, under its title or
// under » when it overflowed. Remote builds only where the gate exists.
function controlPanels(opts) {
    var rows = [
        item({ id: "cp-theme", label: "Appearance…", icon: "appearance", action: { kind: "open", control: "theme" } }),
        item({ id: "cp-bt", label: "Bluetooth", icon: "bluetooth", action: { kind: "open", control: "bt" } }),
        item({ id: "cp-bri", label: "Brightness", icon: "brightness", action: { kind: "open", control: "bri" } }),
    ];
    if (opts && opts.builder)
        rows.push(item({ id: "cp-builder", label: "Remote builds", icon: "builder", action: { kind: "open", control: "builder" } }));
    rows.push(item({ id: "cp-vol", label: "Sound", icon: "volume-2", action: { kind: "open", control: "vol" } }));
    rows.push(item({ id: "cp-wifi", label: "Wi-Fi", icon: "wifi-4", action: { kind: "open", control: "wifi" } }));
    return rows;
}

// Recent Applications ▸, most recent first, from Launcher.recent. An entry
// is { id, name, icon, kind, argv? }; the Desktop launches it again
// through Launcher.
function recentRows(recent) {
    var list = (recent || []).filter(function (r) { return r && (r.name || r.id); });
    if (list.length === 0)
        return [item({ id: "recent-none", label: "No recent applications", disabled: true, spacer: true })];
    return list.slice(0, 15).map(function (r, i) {
        return item({ id: "recent-" + i, label: r.name || r.id, app: r.icon || "", spacer: !r.icon,
                      hint: r.kind === "webapp" ? "web app" : "", action: { kind: "launchRecent", entry: r } });
    });
}

// The Apple menu: launch and find (things not running yet), and the system.
// opts: { host, builder, recent, webApps: [{ id, name, icon }] }
function apple(opts) {
    var o = opts || {};
    var host = o.host ? o.host.charAt(0).toUpperCase() + o.host.slice(1) : "This Computer";
    var rows = [
        item({ id: "about", label: "About " + host + "…", spacer: true, action: { kind: "about" } }),
        sep(),
        item({ id: "cp", label: "Control Panels", icon: "folder", submenu: controlPanels(o) }),
        item({ id: "recent", label: "Recent Applications", icon: "folder", submenu: recentRows(o.recent) }),
    ];
    var apps = (o.webApps || []).slice().sort(function (a, b) {
        return String(a.name).toLowerCase() < String(b.name).toLowerCase() ? -1 : 1;
    });
    for (var i = 0; i < apps.length; i++)
        rows.push(item({ id: "webapp-" + apps[i].id, label: apps[i].name, app: apps[i].icon || "",
                         spacer: !apps[i].icon, action: { kind: "launchWebApp", app: apps[i] } }));
    rows.push(sep());
    rows.push(item({ id: "find", label: "Find…", hint: "Super+P", spacer: true, action: { kind: "find" } }));
    rows.push(sep());
    rows.push(item({ id: "lock", label: "Lock", spacer: true, action: { kind: "session", what: "lock" } }));
    rows.push(item({ id: "sleep", label: "Sleep", spacer: true, action: { kind: "session", what: "sleep" } }));
    rows.push(item({ id: "logout", label: "Log Out…", hint: "Super+Shift+E", spacer: true, action: { kind: "confirm", what: "logout" } }));
    rows.push(item({ id: "restart", label: "Restart…", spacer: true, action: { kind: "confirm", what: "restart" } }));
    rows.push(item({ id: "shutdown", label: "Shut Down…", spacer: true, action: { kind: "confirm", what: "shutdown" } }));
    return rows;
}

// What each confirmation alert says, and its default button.
function alert(what, host) {
    var name = host ? host.charAt(0).toUpperCase() + host.slice(1) : "this computer";
    if (what === "logout") return { title: "Log Out", text: "Are you sure you want to log out? Open windows close without saving.", button: "Log Out" };
    if (what === "restart") return { title: "Restart", text: "Are you sure you want to restart " + name + "? Open windows close without saving.", button: "Restart" };
    if (what === "shutdown") return { title: "Shut Down", text: "Are you sure you want to shut down " + name + "? Open windows close without saving.", button: "Shut Down" };
    return null;
}

// A page label for a window row: "page 3", or "page 3, tablet" on another
// screen. here is this bar's output name; screenLabel names the other one.
function pageLabel(w, here, screenLabel) {
    if (typeof w.workspace === "string" && w.workspace.indexOf("special:hidden-") === 0) return "hidden";
    if (!(w.page > 0)) return "";
    return "page " + w.page + (w.screen && here && w.screen !== here ? ", " + (screenLabel ? screenLabel(w.screen) : w.screen) : "");
}

// The windows of one app, in page order, each with its page.
function windowRows(app, front, here, screenLabel) {
    var list = (app.windows || []).slice();
    var at = list.slice();
    list.sort(function (a, b) {
        var pa = a.page > 0 ? a.page : 1e9, pb = b.page > 0 ? b.page : 1e9;
        return pa - pb || at.indexOf(a) - at.indexOf(b);
    });
    return list.map(function (w) {
        return item({ id: "win-" + w.address, label: w.title || app.name, hint: pageLabel(w, here, screenLabel),
                      check: w.address === front, action: { kind: "activate", address: w.address, appId: app.appId } });
    });
}

// The Application menu: switch what is running.
// opts: { apps (app-model.apps), front (address), frontApp (app id or ""),
//         frontName, othersShown (bool), anyHidden (bool), target (app id
//         Super+Tab is on), here, screenLabel }
function application(opts) {
    var o = opts || {};
    var name = o.frontName || "";
    var rows = [
        item({ id: "hide", label: name ? "Hide " + name : "Hide", disabled: !o.frontApp, spacer: true,
               action: { kind: "hide", appId: o.frontApp } }),
        item({ id: "hideOthers", label: "Hide Others", disabled: !o.othersShown, spacer: true, action: { kind: "hideOthers", appId: o.frontApp } }),
        item({ id: "showAll", label: "Show All", disabled: !o.anyHidden, spacer: true, action: { kind: "showAll" } }),
    ];
    var apps = o.apps || [];
    if (apps.length > 0) rows.push(sep());
    else rows.push(sep(), item({ id: "none", label: "No applications", disabled: true, spacer: true }));
    for (var i = 0; i < apps.length; i++) {
        var a = apps[i];
        rows.push(item({
            id: "app-" + a.appId, label: a.name, app: a.icon, check: a.front, dim: a.hidden,
            count: a.count > 1 ? a.count : 0, highlight: o.target === a.appId,
            submenu: a.count > 1 ? windowRows(a, o.front, o.here, o.screenLabel) : null,
            action: { kind: "switchApp", appId: a.appId },
        }));
    }
    return rows;
}

// A Control Strip tile's menu. opts: { window (row), appName, appIcon,
// front (bool), shown (bool), move (strip-plan movePages result) }
function tile(opts) {
    var w = opts.window, name = opts.appName || w.appId || "Window";
    var state = opts.front ? ", front window" : opts.shown ? "" : ", not showing";
    var pages = opts.move ? opts.move.pages : [];
    var sub = pages.map(function (p) {
        return item({ id: "page-" + p.page, label: p.label, check: p.current, disabled: p.current,
                      action: { kind: "moveTo", address: w.address, page: p.page } });
    });
    if (opts.move) {
        sub.push(sep());
        sub.push(item({ id: "page-new", label: "New page (" + opts.move.newPage + ")",
                        action: { kind: "moveTo", address: w.address, page: opts.move.newPage } }));
    }
    return [
        { kind: "header", label: w.title || name, detail: name + (w.page > 0 ? ", page " + w.page : "") + state, app: opts.appIcon || "" },
        sep(),
        item({ id: "switch", label: opts.front ? "Front window" : "Switch to window", hint: "Click", disabled: !!opts.front,
               action: { kind: "activate", address: w.address, appId: w.appId } }),
        item({ id: "close", label: "Close window", hint: "Middle-click", action: { kind: "close", address: w.address } }),
        sep(),
        item({ id: "move", label: "Move to page", submenu: sub }),
        item({ id: "hideApp", label: "Hide " + name, action: { kind: "hide", appId: w.appId } }),
    ];
}

// The first enabled row at or after `from` in `dir`, wrapping; -1 if none.
function nextEnabled(rows, from, dir) {
    var n = (rows || []).length;
    if (n === 0) return -1;
    for (var step = 1; step <= n; step++) {
        var i = ((from + dir * step) % n + n) % n;
        var r = rows[i];
        if (r && r.kind === "item" && !r.disabled) return i;
    }
    return -1;
}
