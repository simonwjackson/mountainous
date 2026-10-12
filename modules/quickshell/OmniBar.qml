import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import "lanes.js" as Lanes

Scope {
    id: root

    property bool shown: false
    // "root" leads with windows and offers commands; the others scope
    // the field to one list, which is Kamoi's notion of a mode.
    property string mode: "root"
    property string query: ""

    // The window that was focused when the bar was summoned.
    //
    // Kamoi's Ctrl+L acts on the active window, and the veil below takes
    // keyboard focus the instant it maps, so by the time anything is
    // typed the focused window is the veil. Capture it on the way in.
    property var caller: null

    function enterRoot() {
        // Kamoi's list is ordered by focus history, and Hyprland does
        // not push that on every change, so ask for it on open.
        Hyprland.refreshToplevels();
        root.mode = "root";
        root.query = "";
        root.shown = true;
    }

    function enterMode(m) {
        Hyprland.refreshToplevels();
        root.mode = m;
        root.query = "";
        root.shown = true;
    }

    // Kamoi's Ctrl+L: "show and focus browser chrome". An --app window
    // has no chrome to show, so this IS the chrome -- one field that
    // points the active window somewhere else.
    function enterNavigate() {
        if (!root.shown) root.caller = Hyprland.activeToplevel;
        CdpBrowser.refresh();
        root.mode = "nav";
        root.query = "";
        root.shown = true;
    }

    function back() {
        if (root.mode !== "root") { root.mode = "root"; root.query = ""; }
        else root.shown = false;
    }

    IpcHandler {
        target: "omni"
        // Deliberately not named open/show/list/close: `qs ipc call`
        // owns those verbs and silently returns its own interface
        // listing instead of calling the function.
        function toggle(): void { if (root.shown) root.shown = false; else root.enterRoot(); }
        function reveal(): void { root.enterRoot(); }
        function gotowindow(): void { root.enterMode("window"); }
        function apps(): void { root.enterRoot(); }
        function navigate(): void { root.enterNavigate(); }
        function dismiss(): void { root.shown = false; }
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
            root.shown = false;
            return;
        }

        if (row.kind === "app") {
            if (row.entry) row.entry.execute();
            root.shown = false;
            return;
        }

        if (row.kind === "nav") {
            CdpBrowser.navigate(root.caller, row.label);
            root.shown = false;
            return;
        }

        const a = row.act;
        if (a === "mode:nav")    { root.enterNavigate(); return; }
        if (a === "mode:window") { root.enterMode("window"); return; }
        if (a === "mode:app")    { root.enterRoot(); return; }

        if (a === "term")            Quickshell.execDetached(["ghostty"]);
        else if (a === "close") {
            const w = Hyprland.activeToplevel;
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
        else if (a === "shot")       Quickshell.execDetached(["mountainous-screenshot", "screen"]);

        root.shown = false;
    }

    //--------------------------------------------------------------
    // THE VEIL
    //--------------------------------------------------------------
    LazyLoader {
        active: root.shown

        PanelWindow {
            id: veil
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
                onCleared: root.shown = false
            }

            // A click on the veil itself dismisses, as Escape does.
            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
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
                                    root.mode = "root";
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
