pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "glance-plan.js" as GlancePlan
import "glance-registry.js" as Registry
import "themes/win98/fleet-plan.js" as Plan
import "themes/win98/host-icon.js" as HostIcon

// The glance space (Super+wU) in the Windows 98 form (the approved mock
// pass 2): everything but the taskbar goes under Win98's Shut Down checker
// (black on every other Win98 pixel, 2 x 2 device px, the rest the work's
// own colours), and the desk accessories (Fleet, Disks: the shared
// glance-registry.js) stand on it in Clean Up order from the bottom right,
// the shared glance-plan.js mirrored with Win98's margins. Fleet stands
// where the standalone Fleet window does. The taskbar stays live: its
// pressed Glance button opens the Glance menu (a double-click hides the
// space), its window buttons dismiss the space and switch, and Start opens
// over it.
//
// Summon: Win98's caption animation from the Glance button, frames 0-8 (one
// caption bar per accessory flies out), the accessories at frame 9
// (150 ms); dismiss is the mirror, with input back on frame 0. No alpha in
// any frame. Reduced motion is the cut. One layer surface per screen,
// created with the Desktop and only shown and hidden after that.
PanelWindow {
    id: space

    required property var controller
    required property var desktop
    required property var taskbar
    required property var beszel
    required property var storage

    readonly property bool wanted: controller.glanceShown
    // hidden, summoning, shown, dismissing
    property string phase: "hidden"
    property string dir: "in"
    property double t0: 0
    property real elapsed: 0
    readonly property var frame: GlancePlan.frameAt("zoom", space.dir, space.elapsed, GlanceState.reducedMotion)
    readonly property var captionAt: Plan.captionProgress(space.frame)

    screen: desktop.screen
    visible: phase !== "hidden"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    color: "transparent"
    WlrLayershell.namespace: "mountainous-glance"
    WlrLayershell.layer: WlrLayer.Top

    readonly property real u: Kit.Win98Tokens.unitFor(space)
    function units(n) { return n * space.u; }
    // Before the first show the window has no size yet; the screen does.
    readonly property real fullW: width > 0 ? width : (screen ? screen.width : 1920)
    readonly property real fullH: height > 0 ? height : (screen ? screen.height : 1200)
    readonly property real spaceW: fullW
    readonly property real spaceH: Math.max(0, fullH - space.taskbar.barHeight)
    readonly property int wU: Math.floor(spaceW / u + 1e-6)
    // The plan works in the work area the standalone window gets (the
    // screen less the taskbar's whole-pixel zone), so Fleet stands on the
    // same unit in both hosts; the checker still reaches the bar's top.
    readonly property int hU: Math.floor(Math.max(0, fullH - Math.ceil(space.taskbar.barHeight - 1e-6)) / u + 1e-6)

    // Input everywhere but the taskbar, and nowhere while the space leaves.
    mask: Region {
        width: space.phase === "dismissing" ? 0 : space.spaceW
        height: space.phase === "dismissing" ? 0 : space.spaceH
    }

    // Where the captions start (summon) and end (dismiss): the Glance
    // button; before it stands (or when the taskbar has no room for it),
    // the tray's Fleet icon, the chevron that holds it, or Start.
    function originRect() {
        const t = space.taskbar;
        const p = t.placeOf("glance") || t.placeOf("fleet") || t.placeOf("more") || t.placeOf("start");
        const y = space.fullH - t.barHeight + space.units(4);
        return p ? { x: p.x, y: y, w: p.w, h: space.units(22) } : { x: space.fullW - space.units(100), y: y, w: space.units(90), h: space.units(22) };
    }

    Timer {
        id: scrollSettle
        interval: 0
        onTriggered: space.settleScroll()
    }
    Timer {
        id: frontFocus
        interval: 0
        onTriggered: space.focusFront()
    }

    function summon() {
        space.dir = "in";
        space.t0 = Date.now();
        space.elapsed = 0;
        space.phase = "summoning";
        MenuState.close();
        if (space.front === "" || space.planIds.indexOf(space.front) < 0) space.front = space.planIds.length ? space.planIds[0] : "";
        space.scrollToBottom = true;
        scrollSettle.restart();
        frontFocus.restart();
        if (space.frame.done) space.phase = "shown";
    }
    function dismiss() {
        if (space.phase === "hidden") return;
        space.dir = "out";
        space.t0 = Date.now();
        space.elapsed = 0;
        space.phase = "dismissing";
        if (space.frame.done) space.phase = "hidden";
    }
    function close() { space.controller.hideGlance(); }
    // Esc: a menu first, then the Properties sheet, then the space.
    function goBack() {
        if (space.fleetView && space.fleetView.menuOpen !== "") space.fleetView.menuOpen = "";
        else if (space.beszel && space.beszel.expanded !== "") { space.beszel.expanded = ""; space.focusFront(); }
        else space.close();
    }

    onWantedChanged: wanted ? summon() : dismiss()
    Component.onCompleted: if (wanted) summon()

    readonly property bool trace: Quickshell.env("MOUNTAINOUS_GLANCE_TRACE") === "1"
    FrameAnimation {
        running: (space.phase === "summoning" || space.phase === "dismissing") && GlanceState.held < 0
        onTriggered: {
            space.elapsed = (Date.now() - space.t0) / Math.max(1, GlanceState.slow);
            if (space.trace) console.log("glance-trace " + space.dir + " k=" + space.frame.k + " t=" + space.elapsed
                + " caption=" + space.captionAt + " widgets=" + space.frame.widgets + " background=" + space.frame.background);
            if (!space.frame.done) return;
            space.phase = space.dir === "in" ? "shown" : "hidden";
        }
    }

    // The glance IPC's seek: hold one frame of a summon or a dismiss.
    function applyHold() {
        if (!space.desktop.active) return;
        if (GlanceState.held >= 0) {
            space.dir = GlanceState.heldDir;
            space.elapsed = GlanceState.held;
            space.phase = space.dir === "in" ? "summoning" : "dismissing";
        } else {
            space.elapsed = 0;
            space.phase = space.wanted ? "shown" : "hidden";
        }
    }
    Connections {
        target: GlanceState
        function onHeldChanged() { space.applyHold(); }
        function onHeldDirChanged() { if (GlanceState.held >= 0) space.applyHold(); }
    }

    // A click outside the space and the taskbar dismisses it, unless a
    // taskbar menu took the focus: the grab steps aside while one is open.
    HyprlandFocusGrab {
        active: space.visible && (space.phase === "summoning" || space.phase === "shown") && MenuState.current === ""
        windows: [space, space.taskbar]
        onCleared: if (space.wanted && MenuState.current === "") space.close()
    }

    // ---------------------------------------------------------- accessories
    readonly property var available: ({ fleet: space.beszel !== null, disks: space.storage !== null })
    readonly property var wantedIds: Registry.enabledIds(GlanceState.saved.enabled).filter(function (id) { return space.available[id]; })
    // The Repeater's model changes only when the set does.
    property var ids: []
    onWantedIdsChanged: if (JSON.stringify(wantedIds) !== JSON.stringify(ids)) ids = wantedIds
    readonly property var planIds: ids.length ? ids : ["empty"]
    property string front: ""
    // The space is modal: its front window draws the active caption, the
    // Properties sheet while it was the last one pressed.
    property bool sheetFront: false
    property var items: ({})          // id -> accessory
    property var drag: ({})           // id -> {x, y} in units while dragged
    readonly property var fleetView: space.items.fleet ? space.items.fleet.content : null

    // Each accessory at rest, in units (no menu open; the natural height).
    readonly property var restItems: {
        const out = [];
        for (const id of space.planIds) {
            const a = space.items[id];
            if (!a) continue;
            out.push({ id: id, w: a.restW, h: a.restH });
        }
        return out;
    }
    readonly property var plan: GlancePlan.plan(space.wU, space.hU, space.restItems, { gp: Plan.GP, from: "bottom" })
    // Remembered places are kept in logical px (GlanceState, shared with
    // Platinum); the plan works in units.
    readonly property var placesU: {
        const out = {};
        const p = GlanceState.saved.places || {};
        for (const id of Object.keys(p)) out[id] = { r: p[id].r / space.u, t: p[id].t / space.u };
        return out;
    }
    readonly property var rects: GlancePlan.place(space.plan, space.placesU, space.wU, space.hU)

    function focusFront() {
        const a = space.items[space.front];
        if (a && a.content) a.content.forceActiveFocus();
        else keys.forceActiveFocus();
    }
    function cycle(step) {
        const list = space.planIds;
        if (!list.length) return;
        const i = list.indexOf(space.front);
        space.front = list[((i < 0 ? 0 : i) + step + list.length) % list.length];
        space.focusFront();
        space.reveal(space.front);
    }
    // Keyboard travel brings the front accessory into view while the space scrolls.
    function reveal(id) {
        const r = space.rects[id];
        if (!r || !space.plan.scroll) return;
        const y = space.units(r.y), h = space.units(r.h);
        space.scrollToBottom = false;
        if (y < scroller.contentY) scroller.contentY = Math.max(0, y - space.units(4));
        else if (y + h > scroller.contentY + scroller.height)
            scroller.contentY = Math.min(scroller.contentHeight - scroller.height, y + h - scroller.height + space.units(4));
    }
    // The space starts at the bottom (Fleet's slot) each time it shows,
    // and stays there while its content settles, until the reader scrolls.
    property bool scrollToBottom: true
    property bool settling: false
    function settleScroll() {
        if (!space.scrollToBottom) return;
        space.settling = true;
        scroller.contentY = Math.max(0, scroller.contentHeight - scroller.height);
        space.settling = false;
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) { space.goBack(); event.accepted = true; }
            else if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ControlModifier)) { space.cycle(1); event.accepted = true; }
            else if (event.key === Qt.Key_Backtab && !(event.modifiers & Qt.ControlModifier)) { space.cycle(-1); event.accepted = true; }
            else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier) && space.beszel && space.beszel.expanded !== "") {
                space.controller.tab = (space.controller.tab + 1) % 4; event.accepted = true;
            }
        }

        // The background: Win98's Shut Down checker over the work, drawn at
        // the screen's size at startup, so the first summon draws nothing new.
        Item {
            id: field
            width: space.spaceW
            height: space.spaceH
            visible: space.frame.background
            clip: true
            Win98Dither {
                objectName: "glanceDither"
                width: space.units(space.wU + 1)
                height: space.units(space.hU + 1)
                color: "#000000"
                phase: 1
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: space.close()
                onWheel: function (wheel) { wheel.accepted = false; }
            }
        }

        Flickable {
            id: scroller
            width: space.spaceW - space.units(space.plan.sb)
            height: space.spaceH
            contentHeight: space.plan.scroll ? space.units(space.plan.contentH) : height
            onContentHeightChanged: scrollSettle.restart()
            onHeightChanged: scrollSettle.restart()
            // The reader moved it (the scroll bar, the wheel): it stays put.
            onContentYChanged: if (!space.settling && contentY < contentHeight - height - 1) space.scrollToBottom = false
            interactive: false
            boundsBehavior: Flickable.StopAtBounds
            WheelHandler {
                enabled: space.plan.scroll
                onWheel: event => {
                    space.scrollToBottom = false;
                    scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height,
                        scroller.contentY - Math.sign(event.angleDelta.y) * space.units(32)));
                }
            }
            // Hidden until the captions land; still laid out, so the
            // captions know where they go.
            opacity: space.frame.widgets ? 1 : 0

            // A click between accessories reaches the background.
            MouseArea {
                width: scroller.width
                height: scroller.contentHeight
                acceptedButtons: Qt.AllButtons
                onPressed: space.close()
                onWheel: function (wheel) { wheel.accepted = false; }
            }

            Repeater {
                model: space.planIds
                Item {
                    id: acc
                    required property string modelData
                    readonly property var rect: space.rects[modelData] || ({ x: 0, y: 0, w: restW, h: restH })
                    readonly property var dragged: space.drag[modelData] || null
                    readonly property bool isFleet: modelData === "fleet"
                    readonly property var content: loader.item
                    // At rest (no menu open), in units, so opening a menu or
                    // the sheet never moves the other accessories.
                    readonly property real restW: !content ? 230 : isFleet
                        ? Math.min(Math.round(content.naturalWidth / space.u), Math.max(Plan.C.MINW, space.wU - Plan.GP.LEFT - Plan.GP.RIGHT))
                        : Math.round(content.naturalWidth / space.u)
                    readonly property real restH: !content ? 80 : isFleet ? content.naturalUnits : Math.round(content.restHeight / space.u)
                    objectName: "accessory-" + modelData
                    x: space.units(dragged ? dragged.x : rect.x)
                    y: space.units(dragged ? dragged.y : rect.y)
                    width: space.units(rect.w)
                    height: win.height
                    z: space.front === modelData ? 2 : 1

                    Component.onCompleted: { const m = Object.assign({}, space.items); m[modelData] = acc; space.items = m; }
                    Component.onDestruction: { const m = Object.assign({}, space.items); delete m[modelData]; space.items = m; }

                    // A press anywhere on it brings it to the front.
                    TapHandler {
                        gesturePolicy: TapHandler.DragThreshold
                        onPressedChanged: if (pressed) { space.sheetFront = false; if (space.front !== acc.modelData) { space.front = acc.modelData; space.focusFront(); } }
                    }
                    // The caption drags it (not while the space scrolls).
                    MouseArea {
                        x: win.frame
                        y: win.frame
                        width: win.width - 2 * win.frame
                        height: space.units(Kit.Win98Tokens.captionHeight)
                        enabled: acc.modelData !== "empty"
                        property point last
                        preventStealing: true
                        onPressed: function (mouse) {
                            last = mapToItem(scroller.contentItem, mouse.x, mouse.y);
                            if (space.front !== acc.modelData) { space.front = acc.modelData; space.focusFront(); }
                        }
                        onPositionChanged: function (mouse) {
                            if (!pressed || space.plan.scroll) return;
                            const p = mapToItem(scroller.contentItem, mouse.x, mouse.y);
                            const d = Object.assign({}, space.drag);
                            const at = d[acc.modelData] || { x: acc.rect.x, y: acc.rect.y };
                            d[acc.modelData] = {
                                x: Math.max(0, Math.min(space.wU - acc.rect.w, at.x + (p.x - last.x) / space.u)),
                                y: Math.max(0, Math.min(space.hU - 22, at.y + (p.y - last.y) / space.u))
                            };
                            last = p;
                            space.drag = d;
                        }
                        onReleased: {
                            const at = space.drag[acc.modelData];
                            if (!at) return;
                            const r = GlancePlan.remember(Math.round(at.x), Math.round(at.y), acc.rect.w, space.wU, space.plan.sb);
                            GlanceState.place(acc.modelData, r.r * space.u, r.t * space.u);
                            const d = Object.assign({}, space.drag);
                            delete d[acc.modelData];
                            space.drag = d;
                        }
                    }

                    Win98Window {
                        id: win
                        width: acc.width
                        // The accessory takes its natural height, or its slot
                        // when the space has less (its list then scrolls).
                        height: acc.isFleet && acc.content ? acc.content.restHeight
                            : acc.modelData === "disks" && acc.content ? space.units(acc.content.chromeH) + acc.content.implicitHeight
                            : implicitHeight
                        margins: acc.modelData === "empty"
                        active: space.front === acc.modelData && !(sheet.item && space.sheetFront)
                        showClose: acc.modelData !== "empty"
                        title: acc.modelData === "empty" ? "Glance"
                            : acc.isFleet && acc.content ? acc.content.captionText(acc.rect.w - 6 - 16 - 3 - 21 - 8)
                            : Registry.label(acc.modelData)
                        iconName: acc.modelData === "disks" ? "disk-ok" : acc.modelData === "empty" ? "glance" : ""
                        iconItem: acc.isFleet ? fleetIcon : null
                        onCloseClicked: GlanceState.setEnabled(acc.modelData, false)
                        onIconClicked: if (acc.isFleet && acc.content) acc.content.openControlMenu(win)

                        Loader {
                            id: loader
                            width: acc.modelData === "empty" ? win.bodyWidth : win.width - 2 * win.frame
                            sourceComponent: acc.isFleet ? fleetComponent : acc.modelData === "disks" ? disksComponent : emptyComponent
                            onLoaded: {
                                const item = loader.item;
                                if (acc.isFleet) {
                                    item.frameWidth = Qt.binding(function () { return acc.width; });
                                    item.maxFrameHeight = Qt.binding(function () { return space.plan.scroll ? -1 : space.units(acc.rect.h); });
                                    item.active = Qt.binding(function () { return win.active; });
                                } else if (acc.modelData === "disks") {
                                    item.maxFrameHeight = Qt.binding(function () { return space.plan.scroll ? -1 : space.units(acc.rect.h); });
                                }
                                if (item.escapePressed) item.escapePressed.connect(space.goBack);
                            }
                        }
                    }
                }
            }
        }

        Win98ScrollBar {
            visible: space.plan.scroll && space.frame.widgets
            x: space.spaceW - width
            height: space.spaceH
            flickable: scroller
            step: space.units(32)
        }

        // Fleet's Properties: the standalone window's rule, on the top layer
        // of the space.
        Loader {
            id: sheet
            objectName: "glanceSheet"
            readonly property var fleetAcc: space.items.fleet || null
            readonly property var openHost: {
                if (!space.beszel || space.beszel.expanded === "" || !fleetAcc) return null;
                for (const v of space.beszel.fleet.hosts) if (v.name === space.beszel.expanded) return v;
                return null;
            }
            readonly property var place: fleetAcc ? Plan.sheetRect({
                x: fleetAcc.x / space.u, y: (fleetAcc.y - scroller.contentY) / space.u, w: fleetAcc.width / space.u, h: fleetAcc.height / space.u
            }, { x: Plan.GP.LEFT, y: Plan.GP.TOP, w: space.wU - Plan.GP.LEFT - Plan.GP.RIGHT, h: space.hU - Plan.GP.TOP - Plan.GP.BOTTOM }) : null
            active: openHost !== null && space.frame.widgets && space.phase !== "hidden"
            onActiveChanged: if (!active && space.phase === "shown") frontFocus.restart()
            visible: space.frame.widgets
            z: 3
            x: place ? space.units(place.x) : 0
            y: place ? space.units(place.y) : 0
            width: place ? space.units(place.w) : 0
            height: place ? space.units(place.h) : 0
            sourceComponent: Win98FleetProperties {
                width: sheet.width
                height: sheet.height
                panel: space.beszel
                prefs: space.controller
                hv: sheet.openHost
                active: space.sheetFront
                onEscapePressed: space.focusFront()
                Component.onCompleted: { space.sheetFront = true; forceActiveFocus(); }
                TapHandler { onPressedChanged: if (pressed) space.sheetFront = true }
            }
        }

        // The caption animation: one caption bar per accessory, from the
        // Glance button to its caption (summon) or back (dismiss).
        Repeater {
            model: space.captionAt !== null ? space.planIds : []
            Rectangle {
                id: fly
                required property string modelData
                readonly property var acc: space.items[modelData] || null
                readonly property var target: acc ? {
                    x: acc.x + space.units(Kit.Win98Tokens.frame), y: acc.y - scroller.contentY + space.units(Kit.Win98Tokens.frame),
                    w: acc.width - space.units(2 * Kit.Win98Tokens.frame), h: space.units(Kit.Win98Tokens.captionHeight)
                } : ({ x: 0, y: 0, w: 0, h: 0 })
                readonly property var r: Plan.captionRect(space.originRect(), target, space.captionAt === null ? 0 : space.captionAt)
                z: 6
                x: Kit.Win98Tokens.snap(r.x, space.u)
                y: Kit.Win98Tokens.snap(r.y, space.u)
                width: Math.max(space.u, Kit.Win98Tokens.snap(r.w, space.u))
                height: Math.max(space.u, Kit.Win98Tokens.snap(r.h, space.u))
                clip: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Kit.Win98Tokens.caption1 }
                    GradientStop { position: 1; color: Kit.Win98Tokens.caption2 }
                }
                Win98Text {
                    x: space.units(3 + 16 + 3)
                    y: space.units(3)
                    text: fly.modelData === "empty" ? "Glance" : Registry.label(fly.modelData)
                    accessMarks: false
                    bold: true
                    color: Kit.Win98Tokens.captionText
                }
            }
        }

        // Menus and tooltips of the accessories draw here.
        Item {
            id: menuLayer
            width: space.fullW
            height: space.spaceH
            z: 5
        }
    }
    readonly property bool focusedSpace: keys.Window.active

    // For the harness and checks: where everything stands, in logical px.
    function debug() {
        const rect = function (it) {
            if (!it) return null;
            const q = it.mapToItem(null, 0, 0);
            return { x: q.x, y: q.y, w: it.width, h: it.height };
        };
        const acc = {};
        for (const id of Object.keys(space.items)) acc[id] = rect(space.items[id]);
        return {
            phase: space.phase, visible: space.visible, k: space.frame.k, caption: space.captionAt,
            widgets: space.frame.widgets, background: space.frame.background,
            wU: space.wU, hU: space.hU, u: space.u, spaceH: space.spaceH,
            cols: space.plan.cols, gap: space.plan.gap, scroll: space.plan.scroll, contentY: scroller.contentY,
            contentH: scroller.contentHeight, viewH: scroller.height,
            rects: acc, front: space.front, ids: space.planIds,
            sheet: sheet.item ? rect(sheet) : null, sheetBeside: sheet.place ? sheet.place.beside : null,
            origin: space.originRect(), menu: space.fleetView ? space.fleetView.menuOpen : ""
        };
    }

    Component {
        id: fleetIcon
        Win98HostIcon {
            hostStatus: HostIcon.fleetLook(space.beszel.fleet, space.beszel.stale).status
            tone: HostIcon.fleetLook(space.beszel.fleet, space.beszel.stale).tone
        }
    }
    Component {
        id: fleetComponent
        Win98FleetView {
            objectName: "glanceFleetView"
            panel: space.beszel
            prefs: space.controller
            menuLayer: menuLayer
            focus: true
            onCloseRequested: GlanceState.setEnabled("fleet", false)
        }
    }
    Component {
        id: disksComponent
        Win98DisksAccessory {
            panel: space.storage
            focus: true
        }
    }
    // Every accessory turned off: the space says where they come back from.
    Component {
        id: emptyComponent
        FocusScope {
            id: empty
            signal escapePressed
            readonly property real naturalWidth: space.units(230)
            readonly property real restHeight: space.units(Kit.Win98Tokens.frame + Kit.Win98Tokens.captionHeight + 1 + Kit.Win98Tokens.frame + 6 + 8) + column.implicitHeight
            implicitWidth: space.units(230 - 2 * Kit.Win98Tokens.frame - 16)
            implicitHeight: column.implicitHeight
            Keys.onPressed: function (event) { if (event.key === Qt.Key_Escape) { empty.escapePressed(); event.accepted = true; } }
            Column {
                id: column
                width: parent.width
                spacing: space.units(8)
                Win98Text { width: parent.width; wrap: true; bold: true; accessMarks: false; text: "No desk accessories are on" }
                Win98Text {
                    width: parent.width
                    wrap: true
                    accessMarks: false
                    text: "Choose them in the Glance menu: click the Glance button at the right of the taskbar. Fleet comes back with one click here."
                }
                Win98Button {
                    objectName: "glanceShowFleet"
                    visible: space.beszel !== null
                    small: true
                    text: "Show &Fleet"
                    onClicked: GlanceState.setEnabled("fleet", true)
                }
            }
        }
    }
}
