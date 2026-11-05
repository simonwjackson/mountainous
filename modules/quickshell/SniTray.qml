import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import "sni-tray.js" as Sni

// The StatusNotifierItem host, for both themes: one owner at the shell
// root (shell.qml `sniTray`, every Desktop's context.tray). Quickshell's
// SystemTray service registers the host (and the watcher when none
// runs); this owner turns its items into plain rows (sni-tray.js) that
// the Memphis tray row and the Platinum status area draw after their
// built-in controls, and runs what a press asks for.
//
// A harness sets `fixture` (plain items, sni-tray.js shape) and
// `fixtureMenus` ({ key: dbusmenu entries }); presses then only log.
Scope {
    id: tray

    property var fixture: null
    property var fixtureMenus: ({})
    signal fixturePressed(string key, string what)

    readonly property var live: SystemTray.items.values
    function statusName(s) {
        return s === Status.Passive ? "Passive" : s === Status.NeedsAttention ? "NeedsAttention" : "Active";
    }
    readonly property var plainItems: tray.fixture !== null ? tray.fixture : tray.live.map(function (it) {
        return {
            id: it.id, title: it.title, status: tray.statusName(it.status), iconSource: it.icon,
            tooltipTitle: it.tooltipTitle, tooltipDescription: it.tooltipDescription,
            hasMenu: it.hasMenu, onlyMenu: it.onlyMenu
        };
    })
    readonly property var rows: Sni.rows(tray.plainItems)

    function rowFor(key) {
        for (const r of tray.rows) if (r.key === key) return r;
        return null;
    }
    // The live SystemTrayItem behind a row, or null (fixtures, gone).
    function itemFor(key) {
        const r = tray.rowFor(key);
        return r && tray.fixture === null ? tray.live[r.index] || null : null;
    }
    // The item's dbusmenu handle, for SniMenuTree.
    function menuOf(key) {
        const it = tray.itemFor(key);
        return it && it.hasMenu ? it.menu : null;
    }

    function run(key, what) {
        if (tray.fixture !== null) { tray.fixturePressed(key, what); return; }
        const it = tray.itemFor(key);
        if (!it) return;
        if (what === "activate") it.activate();
        else if (what === "secondary") it.secondaryActivate();
    }
    function activate(key) { tray.run(key, "activate"); }
    function secondary(key) { tray.run(key, "secondary"); }
    function scroll(key, delta, horizontal) {
        const it = tray.itemFor(key);
        if (it) it.scroll(delta, !!horizontal);
    }

    // Which icon names the themes' own sets draw (lettermark.js needs a
    // resolved path to tell theme art from hicolor). One scan at start of
    // the icon themes on XDG_DATA_DIRS; "Theme name path" per line.
    property var ownIcons: ({})
    Process {
        id: scan
        running: tray.fixture === null || tray.scanFixtures
        command: ["sh", "-c",
            'IFS=:; for d in ${XDG_DATA_DIRS:-/run/current-system/sw/share}; do '
            + 'for t in Mountainous-platinum Mountainous-memphis Chicago95; do '
            + '[ -d "$d/icons/$t" ] && find -L "$d/icons/$t" -type f \\( -name "*.png" -o -name "*.svg" \\) -printf "$t %f %p\\n" 2>/dev/null; '
            + 'done; done']
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                const out = {};
                for (const line of collector.text.split("\n")) {
                    const m = /^(\S+) (\S+?)\.(?:png|svg) (.+)$/.exec(line);
                    if (!m) continue;
                    if (!out[m[2]]) out[m[2]] = {};
                    if (!out[m[2]][m[1]]) out[m[2]][m[1]] = m[3];
                }
                tray.ownIcons = out;
            }
        }
    }
    property bool scanFixtures: false
    // A path under one of themeId's own icon themes for name, else "".
    function resolvedPath(themeId, name) {
        const sets = themeId === "memphis" ? ["Mountainous-memphis", "Chicago95"] : ["Mountainous-platinum"];
        const found = tray.ownIcons[name] || {};
        for (const s of sets) if (found[s]) return found[s];
        return "";
    }
}
