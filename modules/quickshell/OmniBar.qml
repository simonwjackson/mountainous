import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import "lanes.js" as Lanes
import "find-model.js" as FindModel

Scope {
    id: root

    property bool shown: false
    // "root" leads with windows and offers commands; the others scope
    // the field to one list, which is Kamoi's notion of a mode:
    // "window", "app", "cmd", and "nav" (the address).
    property string mode: "root"
    property string query: ""

    // The window that was focused when the bar was summoned.
    //
    // Kamoi's Ctrl+L acts on the active window, and the surface below takes
    // keyboard focus the instant it maps, so by the time anything is
    // typed the focused window is the surface. Capture it on the way in:
    // on every entry point, not only Ctrl+L (find-model.js enter()).
    property var caller: null
    // The screen the bar opens on: the focused one, captured on the way in.
    property var screen: null

    // A theme that draws the bar itself (Platinum's Find menu) claims the
    // view while its Desktop is active. With no claim, the unthemed card
    // below shows, as it always has (Win98, or a theme without a view).
    property var views: []
    readonly property bool themed: root.views.length > 0
    function claimView(owner) {
        if (owner && root.views.indexOf(owner) < 0) root.views = root.views.concat([owner]);
    }
    function releaseView(owner) {
        const i = root.views.indexOf(owner);
        if (i >= 0) { const next = root.views.slice(); next.splice(i, 1); root.views = next; }
    }

    readonly property var state: ({ shown: root.shown, mode: root.mode, query: root.query, caller: root.caller })
    function apply(next) {
        root.caller = next.caller;
        root.mode = next.mode;
        root.query = next.query;
        root.shown = next.shown;
    }

    // Hyprland.activeToplevel, or the last window that held it while a
    // layer surface (a menu) has the keyboard.
    property var lastActive: null
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { if (Hyprland.activeToplevel) root.lastActive = Hyprland.activeToplevel; }
    }
    function activeWindow() {
        const t = Hyprland.activeToplevel;
        if (t) return t;
        const last = root.lastActive;
        return last && Hyprland.toplevels.values.indexOf(last) >= 0 ? last : null;
    }
    function focusedScreen() {
        const m = Hyprland.focusedMonitor;
        const screens = Quickshell.screens;
        if (m) for (const s of screens) if (s.name === m.name) return s;
        return screens.length > 0 ? screens[0] : null;
    }

    function enterRoot() {
        // Kamoi's list is ordered by focus history, and Hyprland does
        // not push that on every change, so ask for it on open.
        Hyprland.refreshToplevels();
        if (!root.shown) root.screen = root.focusedScreen();
        root.apply(FindModel.enter(root.state, "root", root.activeWindow()));
    }

    // `text` keeps the field ("Search All for “…”").
    function enterMode(m, text) {
        Hyprland.refreshToplevels();
        if (!root.shown) root.screen = root.focusedScreen();
        root.apply(FindModel.enter(root.state, m, root.activeWindow(), typeof text === "string" ? text : ""));
    }

    // Kamoi's Ctrl+L: "show and focus browser chrome". An --app window
    // has no chrome to show, so this IS the chrome -- one field that
    // points the active window somewhere else. `text` starts the field
    // (the Find menu's "Go to Address “…”" row).
    function enterNavigate(text) {
        CdpBrowser.refresh();
        if (!root.shown) root.screen = root.focusedScreen();
        root.apply(FindModel.enter(root.state, "nav", root.activeWindow(), typeof text === "string" ? text : ""));
    }

    function back() { root.apply(FindModel.back(root.state)); }
    function dismiss() { if (root.shown) root.apply(FindModel.close(root.state)); }

    IpcHandler {
        target: "omni"
        // Deliberately not named open/show/list/close: `qs ipc call`
        // owns those verbs and silently returns its own interface
        // listing instead of calling the function.
        function toggle(): void { if (root.shown) root.dismiss(); else root.enterRoot(); }
        function reveal(): void { root.enterRoot(); }
        function gotowindow(): void { root.enterMode("window"); }
        function apps(): void { root.enterMode("app"); }
        function navigate(): void { root.enterNavigate(); }
        function dismiss(): void { root.dismiss(); }
    }

    //--------------------------------------------------------------
    // ROWS
    //--------------------------------------------------------------

    // Kamoi: "the windows behind the one in front, most recently
    // focused first". focusHistoryID is 0 for the focused window, 1 for
    // the one before it, so dropping 0 and sorting ascending makes
    // Enter on an untouched field return to the last window.
    //
    // Every screen's windows, grouped by screen, the focused screen
    // first. The docks keep each screen to its own lane; this list is
    // where a window on the other screen stays reachable.
    readonly property var windowRows: {
        const out = [];
        const all = [...Hyprland.toplevels.values];
        for (const t of all) {
            if (!t.workspace || t.workspace.id <= 0) continue;
            const o = t.lastIpcObject;
            const h = (o && o.focusHistoryID !== undefined) ? o.focusHistoryID : 9999;
            if (h === 0) continue;
            out.push({
                kind: "window",
                label: t.title && t.title !== "" ? t.title : "(untitled)",
                detail: "page " + t.workspace.id,
                page: t.workspace.id,
                appId: t.wayland ? (t.wayland.appId || "") : "",
                order: h,
                screen: Lanes.screenOf(t),
                toplevel: t,
                entry: null
            });
        }
        const here = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        return Lanes.groupRows(out, here);
    }

    readonly property var appRows: {
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (!e) continue;
            const name = e.name && e.name !== "" ? e.name : (e.id || "");
            if (name === "") continue;
            out.push({
                kind: "app",
                label: name,
                detail: e.genericName && e.genericName !== "" ? e.genericName : (e.comment || ""),
                order: 0,
                toplevel: null,
                entry: e
            });
        }
        out.sort(function (a, b) { return a.label.localeCompare(b.label); });
        return out;
    }

    readonly property var commandRows: [
        { kind: "cmd", label: "New terminal",          detail: "Super+N",           act: "term" },
        { kind: "cmd", label: "Go to address",         detail: "Ctrl+L",            act: "mode:nav" },
        { kind: "cmd", label: "Go to window",          detail: "mode",              act: "mode:window" },
        { kind: "cmd", label: "Close window",          detail: "Super+C",           act: "close" },
        { kind: "cmd", label: "Monocle",               detail: "Super+M",           act: "monocle" },
        { kind: "cmd", label: "Zen",                   detail: "Super+Shift+M",     act: "zen" },
        { kind: "cmd", label: "Mirror workspace",      detail: "Super+Shift+G",     act: "mirror" },
        { kind: "cmd", label: "Even / golden split",   detail: "Super+G",           act: "split" },
        { kind: "cmd", label: "Interface scale up",    detail: "Super+=",           act: "scaleup" },
        { kind: "cmd", label: "Interface scale down",  detail: "Super+-",           act: "scaledown" },
        { kind: "cmd", label: "Interface scale 100%",  detail: "Super+0",           act: "scalereset" },
        { kind: "cmd", label: "Toggle bars",           detail: "Super+I",           act: "chrome" },
        { kind: "cmd", label: "Dark appearance",        detail: "Super+D",           act: "theme:dark" },
        { kind: "cmd", label: "Light appearance",       detail: "Super+D",           act: "theme:light" },
        // A toggle. Its detail is the current state; light mode ignores it.
        { kind: "cmd", label: "Desktop theme…", detail: "Appearance", act: "theme:picker" },
        { kind: "cmd", label: "Extra dark appearance",  detail: !Theme.dark ? "dark only" : Theme.extraDark ? "on" : "off",
          act: "theme:extra" },
        { kind: "cmd", label: "Screenshot",            detail: "Super+S",           act: "shot" }
    ]

    function matches(row, q) {
        if (q === "") return true;
        const needle = q.toLowerCase();
        return (row.label || "").toLowerCase().includes(needle)
            || (row.detail || "").toLowerCase().includes(needle)
            || (row.entry && row.entry.id && row.entry.id.toLowerCase().includes(needle));
    }

    // Navigate mode shows the typed address as the actionable row, so
    // Enter always has something to land on, then blends the pages the
    // browser already has open underneath it.
    readonly property var navRows: {
        const q = root.query;
        const out = [];
        if (q !== "") {
            out.push({
                kind: "nav", label: q,
                detail: root.caller && CdpBrowser.isBrowserWindow(root.caller)
                    ? "navigate this window" : "open in a new window",
                order: 0, toplevel: null, entry: null
            });
        }
        for (const p of CdpBrowser.pages) {
            if (q !== "" && !(p.url.toLowerCase().includes(q.toLowerCase())
                           || (p.title || "").toLowerCase().includes(q.toLowerCase()))) continue;
            out.push({
                kind: "nav", label: p.url,
                detail: p.title || "", order: 1, toplevel: null, entry: null
            });
        }
        return out;
    }

    readonly property var rows: {
        const q = root.query;
        if (root.mode === "nav")    return navRows;
        if (root.mode === "window") return windowRows.filter(function (r) { return matches(r, q); });
        if (root.mode === "app")    return appRows.filter(function (r) { return matches(r, q); });
        if (root.mode === "cmd")    return commandRows.filter(function (r) { return matches(r, q); });

        // Root. Empty field leads with windows. Typing puts matching
        // applications and commands first and blends matching windows underneath.
        const w = windowRows.filter(function (r) { return matches(r, q); });
        const a = appRows.filter(function (r) { return matches(r, q); });
        const c = commandRows.filter(function (r) { return matches(r, q); });
        return q === "" ? w.concat(c).concat(a) : a.concat(c).concat(w);
    }

    //--------------------------------------------------------------
    // ACTIVATION
    //--------------------------------------------------------------
    function run(row) {
        if (!row) return;

        if (row.kind === "window") {
            const wl = row.toplevel ? row.toplevel.wayland : null;
            // The Wayland toplevel protocol, not Hyprland.dispatch:
            // dispatcher syntax differs under a Lua config, and
            // activate() also pulls focus to that window's page.
            if (wl) wl.activate();
            root.dismiss();
            return;
        }

        if (row.kind === "app") {
            if (row.entry) Launcher.launchEntry(row.entry);
            root.dismiss();
            return;
        }

        // A Recent Applications row launches its recorded argv again.
        if (row.kind === "recent") {
            const e = row.entry;
            if (e && e.argv) Launcher.launch(e.argv, {id: e.id, name: e.name || e.id, icon: e.icon || "", kind: e.kind === "webapp" ? "webapp" : "app"});
            root.dismiss();
            return;
        }

        if (row.kind === "nav") {
            root.navigateTo(row.label);
            return;
        }

        const a = row.act;
        if (a === "mode:nav")    { root.enterNavigate(); return; }
        if (a === "mode:window") { root.enterMode("window"); return; }
        if (a === "mode:app")    { root.enterMode("app"); return; }
        if (a === "mode:cmd")    { root.enterMode("cmd"); return; }
        if (a === "mode:root")   { root.enterRoot(); return; }

        if (a === "term")            Launcher.launch(["ghostty"], {id: "com.mitchellh.ghostty", name: "Ghostty", icon: "com.mitchellh.ghostty", kind: "app"});
        else if (a === "close") {
            // The window the bar was summoned over, not the bar's surface.
            const w = root.caller || Hyprland.activeToplevel;
            if (w && w.wayland) w.wayland.close();
        }
        else if (a === "monocle")    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\" })"]);
        else if (a === "zen")        Quickshell.execDetached(["hypr-zen"]);
        else if (a === "mirror")     Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.layout(\"orientationcycle left right\")"]);
        else if (a === "split")      Quickshell.execDetached(["hypr-split"]);
        else if (a === "scaleup")    Quickshell.execDetached(["hypr-scale", "up"]);
        else if (a === "scaledown")  Quickshell.execDetached(["hypr-scale", "down"]);
        else if (a === "scalereset") Quickshell.execDetached(["hypr-scale", "reset"]);
        else if (a === "chrome")     Quickshell.execDetached(["qs", "-c", "mountainous", "ipc", "call", "chrome", "toggle"]);
        else if (a === "theme:dark")   Quickshell.execDetached(["desktop-theme", "dark"]);
        else if (a === "theme:light")  Quickshell.execDetached(["desktop-theme", "light"]);
        else if (a === "theme:picker") ThemePicker.open();
        else if (a === "theme:extra")  Quickshell.execDetached(["desktop-theme", "extra", "toggle"]);
        else if (a === "shot")       Quickshell.execDetached(["mountainous-screenshot", "screen"]);

        root.dismiss();
    }

    // Point the window the bar was summoned over at an address: CDP when it
    // is a browser page, else a new web-app window (CdpBrowser.navigate).
    function navigateTo(text) {
        const t = (text || "").trim();
        if (t === "") return;
        CdpBrowser.navigate(root.caller, t);
        root.dismiss();
    }

    //--------------------------------------------------------------
    // THE VEIL
    //--------------------------------------------------------------
    // The unthemed card: Win98's Super+P and Start > Run…, and any theme
    // that does not draw the bar itself (themes.md: the omni bar stays
    // unthemed). A theme with its own view claims it with claimView().
    LazyLoader {
        active: root.shown && !root.themed

        PanelWindow {
            id: veil
            // The focused screen, captured when the bar was summoned.
            screen: root.screen
            anchors { top: true; bottom: true; left: true; right: true }
            // Cover the screen without reserving any of it; the bars
            // own the exclusive zones.
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            color: Theme.bgVeil

            // Kamoi: "a captured pointer event cannot reach a page
            // behind the bar". hyprland_focus_grab_v1 keeps keyboard
            // focus here and reports an outside click as `cleared`.
            HyprlandFocusGrab {
                active: root.shown
                windows: [ veil ]
                onCleared: root.dismiss()
            }

            // A click on the veil itself dismisses, as Escape does.
            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss()
            }

            Rectangle {
                id: card
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(parent.height * 0.12)
                width: Math.min(680, parent.width - 80)
                height: Math.min(field.height + list.contentHeight + 18,
                                 parent.height - anchors.topMargin - 60)
                radius: Theme.radiusLarge
                color: Theme.bgPanel
                border.width: 1
                border.color: Theme.borderMuted

                // Swallow clicks on the card so the veil's dismiss
                // handler does not fire underneath it.
                MouseArea { anchors.fill: parent }

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Row {
                        id: field
                        width: parent.width
                        height: 30
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.mode === "root" ? ">"
                                : root.mode === "window" ? "window"
                                : root.mode === "nav" ? "go"
                                : root.mode === "cmd" ? "cmd"
                                : "app"
                            color: Theme.textHint
                            font.pixelSize: 13
                            font.family: Theme.fontFamily
                        }

                        TextInput {
                            id: input
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
                            focus: true
                            color: Theme.textInput
                            font.pixelSize: 14
                            font.family: Theme.fontFamily
                            selectByMouse: true
                            text: root.query
                            onTextChanged: {
                                root.query = text;
                                list.currentIndex = 0;
                            }

                            Keys.onEscapePressed: root.back()
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onUpPressed: list.decrementCurrentIndex()
                            Keys.onReturnPressed: root.run(root.rows[list.currentIndex])
                            Keys.onEnterPressed: root.run(root.rows[list.currentIndex])
                            Keys.onTabPressed: list.incrementCurrentIndex()

                            // Kamoi: "Backspace on an empty field leaves
                            // the mode too."
                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Backspace && text === "" && root.mode !== "root") {
                                    root.enterRoot();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    ListView {
                        id: list
                        width: parent.width
                        height: parent.height - field.height - parent.spacing
                        clip: true
                        model: root.rows
                        currentIndex: 0
                        keyNavigationWraps: true

                        delegate: Item {
                            id: rowItem
                            required property var modelData
                            required property int index
                            width: list.width
                            height: heading.visible ? 26 + heading.height : 26

                            // The first window of each screen's group
                            // names the screen. Only drawn when windows
                            // sit on more than one screen.
                            readonly property bool startsGroup: Lanes.startsGroup(root.rows, index)

                            Text {
                                id: heading
                                visible: rowItem.startsGroup
                                x: 8
                                height: 20
                                verticalAlignment: Text.AlignBottom
                                bottomPadding: 3
                                text: Lanes.screenLabel(rowItem.modelData.screen || "")
                                color: Theme.textHint
                                font.pixelSize: 10
                                font.family: Theme.fontFamily
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 0.8
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 26
                                color: index === list.currentIndex ? Theme.bgSelected : "transparent"
                                radius: Theme.radiusSmall

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { list.currentIndex = index; root.run(modelData); }
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20
                                        text: modelData.kind === "window" ? "\u25a0"
                                            : modelData.kind === "app" ? "\u25cf"
                                            : modelData.kind === "nav" ? "\u2192" : "\u203a"
                                        color: Theme.textDim
                                        font.pixelSize: 11
                                        font.family: Theme.fontFamily
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 150
                                        elide: Text.ElideRight
                                        text: modelData.label
                                        color: Theme.textPrimary
                                        font.pixelSize: 12
                                        font.family: Theme.fontFamily
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.detail || ""
                                        color: Theme.textDetail
                                        font.pixelSize: 11
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
