import Hensou as Kit
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "desktop-icons-model.js" as Model

// The desktop icons on the primary screen, in both themes (Hensou
// docs/design/desktop-icons.md). Hensou Files supplies the icons and acts
// on them over its desktop socket (DesktopIconSession); this layer draws
// them on the desktop's own background surface (DesktopPattern.qml),
// under every window, and turns input into intents: select, rubber band,
// open, move, drop, rename, the context menus and the confirmations.
// desktop-icons-model.js holds every rule; this file wires and draws.
FocusScope {
    id: root

    required property var screen
    // The background surface (DesktopPattern), for the rename focus grab.
    required property var window
    property string themeId: Theme.name === "memphis" ? "memphis" : "platinum"
    property real devicePixelRatio: root.window && root.window.devicePixelRatio > 0 ? root.window.devicePixelRatio : 1.5

    readonly property bool memphis: root.themeId === "memphis"
    readonly property var layout: root.width > 0 && root.height > 0
        ? Model.screenLayout(root.themeId, { name: root.screen ? root.screen.name : "", width: root.width, height: root.height, scale: root.devicePixelRatio })
        : null
    readonly property var usable: root.layout ? root.layout.usable : { x: 0, y: 0, width: 0, height: 0 }
    readonly property var icons: session.icons
    readonly property var grid: session.grid
    // The surface takes clicks only while there are live icons to act on.
    readonly property bool takesInput: session.shown

    // ---- state
    property var selection: []
    property string anchorId: ""
    property string focusId: ""
    // Positions sent in a Move, drawn until the provider's answer arrives.
    property var pending: ({})
    // The open menu, alert and rename.
    property var menu: null        // { rows, x, y, ids, id }
    property var alertSpec: null
    property string renamingId: ""

    DesktopIconSession {
        id: session
        theme: root.themeId
        layout: root.layout
        onConfirmNeeded: function (effect) { root.confirm(effect); }
        onFailed: function (effect) { root.showError(effect); }
        onProviderChanged: function (effect) {
            const next = Object.assign({}, root.pending);
            for (const id of effect.upsert.concat(effect.removed)) delete next[id];
            root.pending = next;
            root.prune();
        }
        onShownChanged: if (!shown) root.reset()
    }
    readonly property var connection: session

    // Runs when the provider goes away. A confirmation the user has not
    // answered yet (Empty Trash with its count, a permanent delete) belonged
    // to the old connection: drop it, so it can never act on a new one.
    function reset() {
        root.selection = [];
        root.focusId = "";
        root.pending = {};
        root.menu = null;
        root.alertSpec = null;
        root.renamingId = "";
    }
    // Drop ids the provider removed.
    function prune() {
        const have = {};
        for (const i of root.icons) have[i.id] = true;
        root.selection = root.selection.filter(function (id) { return have[id]; });
        if (root.focusId !== "" && !have[root.focusId]) root.focusId = "";
        if (root.renamingId !== "" && !have[root.renamingId]) root.renamingId = "";
    }
    onIconsChanged: root.prune()
    onThemeIdChanged: { root.menu = null; root.alertSpec = null; root.renamingId = ""; }

    Timer {
        // A provider that never answers a Move does not leave icons astray.
        id: pendingTimeout
        interval: 1500
        onTriggered: root.pending = {}
    }

    function iconById(id) { return Model.find(root.icons, id); }
    function labels(ids) { return ids.map(root.iconById).filter(Boolean).map(function (i) { return i.label; }); }

    // ---- geometry: each delegate's image and label in this item's px
    function delegateFor(id) {
        for (let k = 0; k < icons_.count; k++) {
            const d = icons_.itemAt(k);
            if (d && d.icon && d.icon.id === id) return d;
        }
        return null;
    }
    function boxes() {
        const out = [];
        for (let k = 0; k < icons_.count; k++) {
            const d = icons_.itemAt(k);
            if (!d || !d.icon) continue;
            const im = d.imageRect, lb = d.labelRect;
            out.push({ id: d.icon.id, z: d.z, rects: [
                { x: d.x + im.x, y: d.y + im.y, w: im.width, h: im.height },
                { x: d.x + lb.x, y: d.y + lb.y, w: lb.width, h: lb.height }] });
        }
        return out;
    }
    // The topmost icon under a point (overlapping icons: the higher z).
    function hitAt(x, y) {
        const bs = root.boxes().sort(function (a, b) { return b.z - a.z; });
        for (const b of bs)
            for (const r of b.rects)
                if (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h) return { id: b.id, label: r === b.rects[1] };
        return null;
    }

    // ---- intents
    function send(message) { return session.send(message); }
    function open(ids) {
        const live = ids.filter(function (id) { const i = root.iconById(id); return i && i.available !== false; });
        if (live.length > 0) root.send({ type: "open", ids: live });
        else if (ids.length === 1) {
            const i = root.iconById(ids[0]);
            if (i && i.reason) root.alertSpec = Model.errorPlan(root.themeId, { code: "other", message: i.reason }, [i.label]);
        }
    }
    function trash(ids) {
        const all = ids.map(root.iconById).filter(Boolean);
        if (all.length === 0 || !all.every(Model.canTrash)) return;
        root.send({ type: "check-trash", request: session.nextRequest(), ids: ids.slice() });
    }
    function runRow(row, ids, id) {
        const a = Model.menuAction(row, ids, id, session.snap, session.request + 1);
        if (!a) return;
        if (a.local === "rename") { root.startRename(a.id); return; }
        if (a.send.request !== undefined) session.nextRequest();
        root.send(a.send);
    }
    function confirm(effect) {
        const plan = Model.confirmPlan(root.themeId, effect.confirmation, effect.ids, root.labels(effect.ids));
        if (plan === null) {
            // Platinum's Move to Trash: at once.
            if (effect.confirmation && effect.confirmation.type === "move-to-trash")
                root.send({ type: "trash", ids: effect.ids });
            return;
        }
        root.menu = null;
        root.alertSpec = plan;
    }
    function showError(effect) {
        root.alertSpec = Model.errorPlan(root.themeId, effect, root.labels(effect.ids));
    }
    function alertDone(accepted) {
        const spec = root.alertSpec;
        root.alertSpec = null;
        if (accepted && spec && spec.send) root.send(spec.send);
        root.forceActiveFocus();
    }

    // ---- menus
    function openMenu(x, y, id) {
        MenuState.close();
        const ids = id ? root.selection.slice() : [];
        const rows = id ? Model.iconMenu(root.themeId, root.icons, ids, id) : Model.desktopMenu(root.themeId, session.snap);
        if (rows.length === 0) return;
        root.menu = { rows: rows, x: x, y: y, ids: ids, id: id || "" };
    }
    Connections {
        target: MenuState
        // Another menu opened: this one closes (one menu at a time).
        function onCurrentChanged() { if (MenuState.current !== "") root.menu = null; }
    }

    // ---- rename
    function startRename(id) {
        const icon = root.iconById(id);
        if (!Model.canRename(icon)) return;
        root.menu = null;
        root.selection = [id];
        root.focusId = id;
        root.renamingId = id;
    }
    function endRename(commit) {
        if (root.renamingId === "") return;
        const icon = root.iconById(root.renamingId);
        const name = commit ? Model.renameTo(icon, renameField.text) : "";
        root.renamingId = "";
        if (name !== "") root.send({ type: "rename", id: icon.id, name: name });
        root.forceActiveFocus();
    }
    Timer {
        // A click on the name of the one selected icon renames it, unless
        // a second click makes it a double-click first.
        id: renameSoon
        property string id: ""
        interval: 550
        onTriggered: if (root.selection.length === 1 && root.selection[0] === id) root.startRename(id)
    }

    // ---- the pointer
    property string mode: ""           // "", "press", "drag", "band"
    property string pressId: ""
    property bool pressOnLabel: false
    property bool pressWasSelected: false
    property var pressMods: ({})
    property point pressAt: Qt.point(0, 0)
    property real dragDx: 0
    property real dragDy: 0
    property var dragIds: []
    property string dropId: ""
    property var bandRect: null
    property var bandBase: []

    function modsOf(mouse) {
        return { shift: (mouse.modifiers & Qt.ShiftModifier) !== 0, ctrl: (mouse.modifiers & Qt.ControlModifier) !== 0 };
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.takesInput
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: false

        onPressed: function (mouse) {
            root.forceActiveFocus();
            if (root.renamingId !== "") root.endRename(true);
            const hit = root.hitAt(mouse.x, mouse.y);
            const mods = root.modsOf(mouse);
            if (mouse.button === Qt.RightButton) {
                if (hit) {
                    if (root.selection.indexOf(hit.id) < 0) root.selection = [hit.id];
                    root.focusId = hit.id;
                } else {
                    root.selection = [];
                }
                root.openMenu(mouse.x, mouse.y, hit ? hit.id : "");
                return;
            }
            root.pressAt = Qt.point(mouse.x, mouse.y);
            root.pressMods = mods;
            if (hit) {
                root.pressWasSelected = root.selection.length === 1 && root.selection[0] === hit.id;
                const c = Model.click(root.themeId, root.icons, root.selection, root.anchorId, hit.id, mods);
                root.selection = c.selection;
                root.anchorId = c.anchor;
                root.focusId = hit.id;
                root.pressId = hit.id;
                root.pressOnLabel = hit.label;
                root.mode = "press";
            } else {
                root.bandBase = mods.shift || mods.ctrl ? root.selection.slice() : [];
                if (!(mods.shift || mods.ctrl)) root.selection = [];
                root.mode = "band";
                root.bandRect = null;
            }
        }
        onPositionChanged: function (mouse) {
            const dx = mouse.x - root.pressAt.x, dy = mouse.y - root.pressAt.y;
            if (root.mode === "press" && Math.hypot(dx, dy) >= Model.DRAG_THRESHOLD && root.selection.indexOf(root.pressId) >= 0) {
                root.mode = "drag";
                renameSoon.stop();
                root.dragIds = root.selection.slice();
            }
            if (root.mode === "drag") {
                root.dragDx = dx;
                root.dragDy = dy;
                root.dropId = Model.dropTarget(root.icons, root.boxes(), mouse.x, mouse.y, root.dragIds);
            } else if (root.mode === "band") {
                const r = Model.band(root.pressAt.x, root.pressAt.y, mouse.x, mouse.y);
                root.bandRect = r;
                root.selection = Model.bandSelection(root.boxes(), r, root.bandBase, root.bandBase.length > 0);
            }
        }
        onReleased: function (mouse) {
            if (root.mode === "drag") {
                const message = Model.endDrag(root.icons, root.dragIds, root.dropId, root.dragDx, root.dragDy, root.usable, root.grid);
                if (message && message.type === "move") {
                    const next = Object.assign({}, root.pending);
                    for (const m of message.moves) next[m[0]] = m[1];
                    root.pending = next;
                    pendingTimeout.restart();
                }
                if (message) root.send(message);
            } else if (root.mode === "press") {
                const wasSelected = root.pressWasSelected;
                root.selection = Model.release(root.selection, root.pressId, root.pressMods, false);
                if (wasSelected && root.pressOnLabel && !root.pressMods.shift && !root.pressMods.ctrl) {
                    renameSoon.id = root.pressId;
                    renameSoon.restart();
                }
            }
            root.mode = "";
            root.dragIds = [];
            root.dropId = "";
            root.dragDx = 0;
            root.dragDy = 0;
            root.bandRect = null;
        }
        onCanceled: { root.mode = ""; root.dragIds = []; root.dropId = ""; root.bandRect = null; }
        onDoubleClicked: function (mouse) {
            renameSoon.stop();
            if (mouse.button !== Qt.LeftButton) return;
            const hit = root.hitAt(mouse.x, mouse.y);
            if (hit) root.open(root.selection.indexOf(hit.id) >= 0 ? root.selection : [hit.id]);
        }
    }

    // ---- the keyboard (focus on demand: the surface takes it on a click)
    function moveFocus(id, mods) {
        if (id === "") return;
        root.focusId = id;
        if (mods && mods.ctrl && root.memphis) return;   // Memphis: Ctrl moves focus only
        root.selection = [id];
        root.anchorId = id;
    }
    Keys.onPressed: function (event) {
        if (!root.takesInput || root.renamingId !== "") return;
        const mods = { shift: (event.modifiers & Qt.ShiftModifier) !== 0, ctrl: (event.modifiers & Qt.ControlModifier) !== 0 };
        const from = root.focusId !== "" ? root.focusId : (root.selection.length > 0 ? root.selection[0] : "");
        const dirs = {};
        dirs[Qt.Key_Left] = "left"; dirs[Qt.Key_Right] = "right"; dirs[Qt.Key_Up] = "up"; dirs[Qt.Key_Down] = "down";
        if (dirs[event.key] !== undefined) {
            root.moveFocus(Model.neighbour(root.boxes(), from, dirs[event.key]), mods);
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.moveFocus(Model.tabNext(root.icons, from, event.key === Qt.Key_Backtab || mods.shift), {});
        } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            root.moveFocus(Model.edge(root.boxes(), event.key === Qt.Key_End), mods);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selection.length > 0) root.open(root.selection);
        } else if (event.key === Qt.Key_Delete) {
            if (root.selection.length > 0) root.trash(root.selection);
        } else if (event.key === Qt.Key_F2) {
            if (root.selection.length === 1) root.startRename(root.selection[0]);
        } else if (event.key === Qt.Key_Escape) {
            root.selection = [];
        } else if (event.key === Qt.Key_A && mods.ctrl) {
            root.selection = root.icons.map(function (i) { return i.id; });
        } else if (event.key === Qt.Key_Space && mods.ctrl && root.memphis && from !== "") {
            const c = Model.click(root.themeId, root.icons, root.selection, root.anchorId, from, { ctrl: true });
            root.selection = c.selection;
        } else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && mods.shift)) {
            const d = root.delegateFor(from);
            if (d && root.selection.indexOf(from) >= 0) root.openMenu(d.x + d.width / 2, d.y + d.height / 2, from);
            else root.openMenu(root.usable.x + 16, root.usable.y + 16, "");
        } else if (event.text !== "" && /\S/.test(event.text) && !mods.ctrl) {
            root.moveFocus(Model.byLetter(root.icons, from, event.text), {});
        } else {
            return;
        }
        event.accepted = true;
    }

    // ---- drawing
    Repeater {
        id: icons_
        model: root.icons
        DesktopIconItem {
            required property var modelData
            readonly property var at: root.pending[modelData.id] || modelData.position
            readonly property bool moving: root.mode === "drag" && root.dragIds.indexOf(modelData.id) >= 0
            icon: modelData
            themeId: root.themeId
            cellWidth: root.grid.cell_width
            cellHeight: root.grid.cell_height
            devicePixelRatio: root.devicePixelRatio
            selected: root.selection.indexOf(modelData.id) >= 0
            focused: root.focusId === modelData.id
            keyboard: root.activeFocus
            dropTarget: root.dropId === modelData.id
            dragging: moving
            renaming: root.renamingId === modelData.id
            x: Math.round((root.usable.x + at.x + (moving ? root.dragDx : 0)) * root.devicePixelRatio) / root.devicePixelRatio
            y: Math.round((root.usable.y + at.y + (moving ? root.dragDy : 0)) * root.devicePixelRatio) / root.devicePixelRatio
            z: Model.zFor(root.icons, modelData.id, root.selection, root.focusId) + (moving ? 10000 : 0)
        }
    }

    // The rubber band: Platinum's dotted grey outline, Memphis's dotted
    // XOR-looking (black and white) rectangle.
    Canvas {
        id: bandShape
        visible: root.bandRect !== null
        z: 30000
        x: root.bandRect ? root.bandRect.x : 0
        y: root.bandRect ? root.bandRect.y : 0
        width: root.bandRect ? Math.max(1, root.bandRect.w) : 1
        height: root.bandRect ? Math.max(1, root.bandRect.h) : 1
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const hair = 1 / root.devicePixelRatio;
            c.lineWidth = hair;
            const draw = function (colour, offset) {
                c.strokeStyle = colour;
                c.setLineDash([2, 2]);
                c.lineDashOffset = offset;
                c.strokeRect(hair / 2, hair / 2, width - hair, height - hair);
            };
            if (root.memphis) { draw("#ffffff", 0); draw("#000000", 2); }
            else draw(Theme.mode === "light" ? "#404040" : "#c0c0c0", 0);
        }
    }

    // Inline rename: a field over the name, in the theme's own look.
    Rectangle {
        id: renameBox
        readonly property var target: root.renamingId !== "" ? root.delegateFor(root.renamingId) : null
        visible: target !== null
        z: 30001
        readonly property real pad: root.memphis ? 2 / root.devicePixelRatio : 2
        width: Math.max(target ? target.labelRect.width + 12 : 60, renameField.contentWidth + 2 * pad + 8)
        height: renameField.implicitHeight + 2 * pad
        x: target ? Math.round(target.x + target.width / 2 - width / 2) : 0
        y: target ? target.y + target.labelRect.y - pad : 0
        color: root.memphis ? Kit.MemphisTokens.win : Kit.PlatinumTokens.field
        border.width: 1 / root.devicePixelRatio
        border.color: "#000000"
        TextInput {
            id: renameField
            x: renameBox.pad + 2
            y: renameBox.pad
            width: renameBox.width - 2 * renameBox.pad - 4
            color: root.memphis ? Kit.MemphisTokens.winText : Kit.PlatinumTokens.menuText
            selectionColor: root.memphis ? Kit.MemphisTokens.selection : Kit.PlatinumTokens.highlight
            selectedTextColor: "#ffffff"
            font.family: root.memphis ? Kit.MemphisTokens.fontFamily : Kit.PlatinumTokens.platinumFont
            font.pixelSize: root.memphis ? Math.round(12.5 * 2 / root.devicePixelRatio) : Kit.PlatinumTokens.platinumSmall
            horizontalAlignment: TextInput.AlignHCenter
            selectByMouse: true
            Keys.onReturnPressed: root.endRename(true)
            Keys.onEnterPressed: root.endRename(true)
            Keys.onEscapePressed: root.endRename(false)
            onActiveFocusChanged: if (!activeFocus && root.renamingId !== "") root.endRename(true)
        }
    }
    onRenamingIdChanged: {
        if (root.renamingId === "") return;
        const icon = root.iconById(root.renamingId);
        renameField.text = icon ? icon.label : "";
        // The name without its extension is selected, as both OSes did
        // for files (Memphis selected all; Mac OS 8 all as well: the
        // extension rule is newer). Select all.
        renameField.selectAll();
        renameField.forceActiveFocus();
    }
    // Keep the keyboard on the desktop while renaming.
    HyprlandFocusGrab {
        active: root.renamingId !== "" && !!root.window
        windows: root.window ? [root.window] : []
        onCleared: root.endRename(true)
    }

    // ---- the menus and alerts, over every window
    LazyLoader {
        active: root.menu !== null
        DesktopIconMenu {
            modelData: root.screen
            themeId: root.themeId
            rows: root.menu ? root.menu.rows : []
            atX: root.menu ? root.menu.x : 0
            atY: root.menu ? root.menu.y : 0
            onChosen: function (row) {
                const m = root.menu;
                Qt.callLater(function () { root.menu = null; if (m) root.runRow(row, m.ids, m.id); });
            }
            onDismissed: Qt.callLater(function () { root.menu = null; })
        }
    }
    LazyLoader {
        active: root.alertSpec !== null
        DesktopIconAlert {
            modelData: root.screen
            themeId: root.themeId
            spec: root.alertSpec
            onAccepted: Qt.callLater(root.alertDone, true)
            onCancelled: Qt.callLater(root.alertDone, false)
        }
    }
}
