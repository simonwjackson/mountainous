// DEV HARNESS (not delivered): the real DesktopPattern with the desktop
// icon layer on, against a desktop provider (Hensou's hensou-desktop-stub
// or provider.js), with stand-ins for the theme's bar so the usable area
// shows. Staged as shell.qml in a copy of modules/quickshell; session.sh
// starts it, capture.sh and behaviour.sh drive it over IPC ("desk").
import Hensou as Kit
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "desktop-icons-model.js" as Model

ShellRoot {
    id: root

    readonly property var screen0: Quickshell.screens[0]
    readonly property var layer: pattern.iconLayer
    readonly property bool win98: Theme.name === "win98"

    // The desktop under everything, with the icons (primary screen).
    DesktopPattern {
        id: pattern
        screen: root.screen0
        desktopIcons: true
    }

    // Stand-ins for the bars the icons keep clear of: Platinum's menu bar
    // and Control Strip band, Memphis's taskbar. Not the real chrome.
    PanelWindow {
        screen: root.screen0
        visible: !root.win98
        anchors { top: true; left: true; right: true }
        implicitHeight: Kit.PlatinumTokens.barHeight
        exclusiveZone: 0
        color: Kit.PlatinumTokens.barSurface
        WlrLayershell.namespace: "harness-bar"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Kit.PlatinumTokens.hairFor(QsWindow.window); color: "#000000" }
        Text {
            x: 14; anchors.verticalCenter: parent.verticalCenter
            text: "Menu bar stand-in"
            color: Kit.PlatinumTokens.barText
            font.family: Kit.PlatinumTokens.platinumFont
            font.pixelSize: Kit.PlatinumTokens.platinumText
        }
    }
    PanelWindow {
        screen: root.screen0
        visible: root.win98
        anchors { bottom: true; left: true; right: true }
        readonly property real u: Kit.Win98Tokens.unitFor(QsWindow.window)
        implicitHeight: Math.ceil(28 * u - 1e-6)
        exclusiveZone: 0
        color: Kit.Win98Tokens.face
        WlrLayershell.namespace: "harness-taskbar"
        Rectangle { width: parent.width; height: parent.u; color: Kit.Win98Tokens.li }
        Rectangle { y: parent.u; width: parent.width; height: parent.u; color: Kit.Win98Tokens.hi }
        Win98Text { x: 8 * parent.u; y: 9 * parent.u; text: "Taskbar stand-in"; accessMarks: false }
    }

    // A stand-in app window above the desktop (Bottom layer: above the
    // Background layer, as every window is), for the "under windows" shot.
    property var fakeWindow: null
    PanelWindow {
        screen: root.screen0
        visible: root.fakeWindow !== null
        anchors { top: true; left: true }
        margins.left: root.fakeWindow ? root.fakeWindow[0] : 0
        margins.top: root.fakeWindow ? root.fakeWindow[1] : 0
        implicitWidth: root.fakeWindow ? root.fakeWindow[2] : 10
        implicitHeight: root.fakeWindow ? root.fakeWindow[3] : 10
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "harness-window"
        color: root.win98 ? Kit.Win98Tokens.face : "#ffffff"
        Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#000000"; border.width: 1 }
        Text { anchors.centerIn: parent; text: "App window stand-in"; font.family: Kit.PlatinumTokens.platinumFont; font.pixelSize: 14 }
    }

    function delegate(id) { return root.layer ? root.layer.delegateFor(id) : null; }

    IpcHandler {
        target: "desk"
        // The layer's state, one JSON line.
        function current(): string {
            const l = root.layer;
            if (!l) return JSON.stringify({ ready: false });
            const boxes = {};
            for (const b of l.boxes()) boxes[b.id] = { x: Math.round(b.rects[0].x), y: Math.round(b.rects[0].y), z: b.z };
            return JSON.stringify({
                ready: true, theme: l.themeId, kind: l.connection.kind, shown: l.connection.shown,
                input: l.takesInput, snap: l.connection.snap,
                icons: l.icons.map(function (i) { return i.id; }), labels: l.icons.map(function (i) { return i.label; }),
                selection: l.selection, focus: l.focusId, renaming: l.renamingId, activeFocus: l.activeFocus,
                menu: l.menu ? l.menu.rows.map(function (r) { return r.separator ? "-" : r.label; }) : null,
                alert: l.alertSpec ? { title: l.alertSpec.title, text: l.alertSpec.text, accept: l.alertSpec.accept, cancel: l.alertSpec.cancel, defaultButton: l.alertSpec.defaultButton } : null,
                usable: l.usable, boxes: boxes
            });
        }
        // Where an icon's image centre is, in screen px: "x y".
        function where(id: string): string {
            const d = root.delegate(id);
            if (!d) return "";
            return Math.round(d.x + d.imageRect.x + d.imageRect.width / 2) + " " + Math.round(d.y + d.imageRect.y + d.imageRect.height / 2);
        }
        function labelAt(id: string): string {
            const d = root.delegate(id);
            if (!d) return "";
            return Math.round(d.x + d.labelRect.x + d.labelRect.width / 2) + " " + Math.round(d.y + d.labelRect.y + d.labelRect.height / 2);
        }
        function select(ids: string): void {
            const l = root.layer;
            l.selection = ids === "" ? [] : ids.split(",");
            l.focusId = l.selection.length > 0 ? l.selection[l.selection.length - 1] : "";
        }
        function menu(id: string): void {
            const l = root.layer;
            if (id === "") { l.selection = []; l.openMenu(l.usable.x + 420, l.usable.y + 260, ""); return; }
            const d = root.delegate(id);
            if (l.selection.indexOf(id) < 0) l.selection = [id];
            l.openMenu(d.x + d.width / 2 + 10, d.y + d.imageRect.y + 20, id);
        }
        function trash(ids: string): void { root.layer.trash(ids.split(",")); }
        function emptyTrash(): void { root.layer.send({ type: "check-empty-trash", request: 99 }); }
        function eject(id: string): void { root.layer.send({ type: "eject", id: id }); }
        // A ConfirmNeeded the stub never sends: a permanent delete.
        function permanent(ids: string, reason: string): void {
            const list = ids.split(",");
            root.layer.confirm({ request: 1, ids: list, confirmation: { type: "permanent", count: list.length, reason: reason } });
        }
        function rename(id: string): void { root.layer.startRename(id); }
        function closeAll(): void { root.layer.menu = null; root.layer.alertSpec = null; root.layer.endRename(false); }
        function window(x: int, y: int, w: int, h: int): void { root.fakeWindow = w > 0 ? [x, y, w, h] : null; }
        function settled(): string {
            const l = root.layer;
            return l && (l.connection.kind === "live" || l.connection.kind === "down") ? "yes" : "no";
        }
    }
}
