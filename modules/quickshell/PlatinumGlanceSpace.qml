import Hensou as Kit
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "glance-plan.js" as GlancePlan
import "glance-registry.js" as Registry

// The glance space (Super+W): a Mac OS 8 focus layer. Everything under the
// bar recedes under a 1-bit dither, and the glance widgets (Fleet, Disks)
// stand on it in Clean Up order from the top right. The bar stays live: its
// Fleet readout is the Glance menu's title.
//
// One layer surface per screen, created at startup and only shown and
// hidden, so a summon never waits for a new surface. It covers the screen;
// its input mask leaves the bar out, as PlatinumMenuHost's does, so the
// bar's controls keep working, and the zoom rects can start in the bar.
//
// Summon: zoom rects, 150 ms, from the Fleet readout (a key) or the menu
// item that asked; dismiss: the mirror, with input back on frame 0. No
// alpha in any frame. Reduced motion is an instant cut. See glance-plan.js
// and docs/plans/fleet-glance.md for the timing table.
PanelWindow {
    id: space

    required property var desktop
    required property var bar
    required property var beszel
    required property var storage
    // PlatinumFleetGlance: where the Fleet readout is on the bar.
    property var controller: null

    readonly property bool wanted: desktop.active && GlanceState.glanceScreen === desktop.screen
    // hidden, summoning, shown, dismissing
    property string phase: "hidden"
    property string dir: "in"
    property double t0: 0
    property real elapsed: 0
    property var origin: ({x: 0, y: 0, w: 0, h: 0})
    readonly property var frame: GlancePlan.frameAt("zoom", space.dir, space.elapsed, GlanceState.reducedMotion)

    screen: desktop.screen
    visible: phase !== "hidden"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    color: "transparent"
    WlrLayershell.namespace: "mountainous-glance"
    WlrLayershell.layer: WlrLayer.Top

    readonly property real barH: Kit.PlatinumTokens.barHeight
    readonly property real dpr: devicePixelRatio > 0 ? devicePixelRatio : (QsWindow.window && QsWindow.window.devicePixelRatio > 0 ? QsWindow.window.devicePixelRatio : 1.5)
    function snap(v) { return Math.round(v * space.dpr) / space.dpr; }
    // Before the first show the window has no size yet; the screen does.
    readonly property real spaceW: width > 0 ? width : (screen ? screen.width : 1920)
    readonly property real spaceH: (height > 0 ? height : (screen ? screen.height : 1200)) - barH

    // Input everywhere but the bar, and nowhere while the space leaves.
    mask: Region {
        x: 0
        y: space.barH
        width: space.phase === "dismissing" ? 0 : space.spaceW
        height: space.phase === "dismissing" ? 0 : space.spaceH
    }

    // The readout's place on the bar, in this window's coordinates.
    function readoutRect() {
        const r = space.controller ? space.controller.readoutRect() : null;
        return r || {x: space.spaceW - 40, y: 0, w: 32, h: space.barH};
    }

    function summon() {
        space.origin = GlanceState.origin || space.readoutRect();
        space.dir = "in";
        space.t0 = Date.now();
        space.elapsed = 0;
        space.phase = "summoning";
        MenuState.close();
        if (space.front === "" || space.ids.indexOf(space.front) < 0) space.front = space.ids.length ? space.ids[0] : "";
        Qt.callLater(space.focusFront);
        if (space.frame.done) space.phase = "shown";
    }
    function dismiss() {
        if (space.phase === "hidden") return;
        space.origin = GlanceState.origin || space.readoutRect();
        space.dir = "out";
        space.t0 = Date.now();
        space.elapsed = 0;
        space.phase = "dismissing";
        if (space.frame.done) space.phase = "hidden";
    }
    function close() { GlanceState.hideGlance(null); }

    onWantedChanged: wanted ? summon() : dismiss()
    Component.onCompleted: if (wanted) summon()

    readonly property bool trace: Quickshell.env("MOUNTAINOUS_GLANCE_TRACE") === "1"
    FrameAnimation {
        running: (space.phase === "summoning" || space.phase === "dismissing") && GlanceState.held < 0
        onTriggered: {
            space.elapsed = (Date.now() - space.t0) / Math.max(1, GlanceState.slow);
            if (space.trace) console.log("glance-trace " + space.dir + " k=" + space.frame.k + " t=" + space.elapsed
                + " outlines=" + (space.frame.outlines ? space.frame.outlines.length : 0) + " widgets=" + space.frame.widgets
                + " background=" + space.frame.background);
            if (!space.frame.done) return;
            space.phase = space.dir === "in" ? "shown" : "hidden";
        }
    }

    // The glance IPC's seek: hold one frame of a summon or a dismiss, the
    // same every run, for a filmstrip of the real motion.
    function applyHold() {
        if (!space.desktop.active) return;
        if (GlanceState.held >= 0) {
            space.origin = GlanceState.origin || space.readoutRect();
            space.dir = GlanceState.heldDir;
            space.elapsed = GlanceState.held;
            space.phase = space.dir === "in" ? "summoning" : "dismissing";
            if (space.dir === "in" && (space.front === "" || space.ids.indexOf(space.front) < 0))
                space.front = space.ids.length ? space.ids[0] : "";
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

    // A click outside the space and the bar dismisses it, unless a bar menu
    // took the focus: the grab steps aside while a menu is open.
    HyprlandFocusGrab {
        active: space.visible && (space.phase === "summoning" || space.phase === "shown") && MenuState.current === ""
        windows: [space, space.bar]
        onCleared: if (space.wanted && MenuState.current === "") space.close()
    }

    // ---------------------------------------------------------- widgets
    readonly property var available: ({fleet: space.beszel !== null, disks: space.storage !== null})
    readonly property var wantedIds: Registry.enabledIds(GlanceState.saved.enabled).filter(function (id) { return space.available[id]; })
    // The Repeater's model changes only when the set does.
    property var ids: []
    onWantedIdsChanged: if (JSON.stringify(wantedIds) !== JSON.stringify(ids)) ids = wantedIds
    readonly property var planIds: ids.length ? ids : ["empty"]
    property string front: ""
    property var items: ({})          // id -> windoid
    property var drag: ({})           // id -> {x, y} while dragged

    readonly property var restItems: {
        const out = [];
        for (const id of space.planIds) {
            const w = space.items[id];
            if (!w) continue;
            out.push({id: id, w: w.restW, h: w.restH});
        }
        return out;
    }
    readonly property var plan: GlancePlan.plan(space.spaceW, space.spaceH, space.restItems)
    readonly property var rects: GlancePlan.place(space.plan, GlanceState.saved.places, space.spaceW, space.spaceH)

    function focusFront() {
        const w = space.items[space.front];
        if (w && w.content) w.content.forceActiveFocus();
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
    // Keyboard travel brings the front widget into view while the space scrolls.
    function reveal(id) {
        const r = space.rects[id];
        if (!r || !space.plan.scroll) return;
        if (r.y < scroller.contentY) scroller.contentY = Math.max(0, r.y - 6);
        else if (r.y + r.h > scroller.contentY + scroller.height)
            scroller.contentY = Math.min(scroller.contentHeight - scroller.height, r.y + r.h - scroller.height + 6);
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) { space.close(); event.accepted = true; }
            else if (event.key === Qt.Key_Tab) { space.cycle(1); event.accepted = true; }
            else if (event.key === Qt.Key_Backtab) { space.cycle(-1); event.accepted = true; }
        }

        // The background: the work recedes. Drawn at startup at the
        // screen's size, so the first summon draws nothing new.
        Item {
            id: field
            y: space.barH
            width: space.spaceW
            height: space.spaceH
            visible: space.frame.background

            PlatinumPattern {
                visible: !PlatinumGlanceTokens.ditherSolid
                width: field.width
                height: field.height
                drawWidth: space.screen ? space.screen.width : field.width
                drawHeight: space.screen ? space.screen.height - space.barH : field.height
                cell: PlatinumGlanceTokens.ditherCell
                ink: PlatinumGlanceTokens.ditherInk
                ground: PlatinumGlanceTokens.ditherGround
                originY: Math.round(space.barH * space.dpr)
            }
            Rectangle {
                visible: PlatinumGlanceTokens.ditherSolid
                anchors.fill: parent
                color: PlatinumGlanceTokens.solidGround
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
            y: space.barH
            width: space.spaceW - space.plan.sb
            height: space.spaceH
            contentHeight: space.plan.scroll ? space.plan.contentH : height
            interactive: space.plan.scroll
            boundsBehavior: Flickable.StopAtBounds
            // Hidden until the zoom lands; still laid out, so the outlines
            // know where they go.
            opacity: space.frame.widgets ? 1 : 0

            // A click between widgets reaches the background.
            MouseArea {
                width: scroller.width
                height: scroller.contentHeight
                acceptedButtons: Qt.AllButtons
                onPressed: space.close()
                onWheel: function (wheel) { wheel.accepted = false; }
            }

            Repeater {
                model: space.planIds
                PlatinumWindoid {
                    id: widget
                    required property string modelData
                    readonly property var rect: space.rects[modelData] || ({x: 0, y: 0, w: restW, h: restH})
                    readonly property var dragged: space.drag[modelData] || null
                    readonly property bool isFleet: modelData === "fleet"
                    readonly property var content: loader.item
                    // Planned at rest (no host open, not shaded), so opening a
                    // host never moves the other widgets.
                    readonly property real restW: Kit.PlatinumMetrics.even(content ? content.naturalWidth : 300)
                    readonly property real restH: chromeHeight + (content ? content.restBodyHeight : 80)
                    // A widget that grows (an open host) grows down over the
                    // ones below, and stops at the space's edge; while the
                    // space scrolls it takes the height it needs.
                    readonly property real cap: space.plan.scroll ? -1
                        : rect.h < restH - 0.5 ? rect.h : Math.max(chromeHeight + 40, space.spaceH - 8 - y)

                    x: space.snap(dragged ? dragged.x : rect.x)
                    y: space.snap(dragged ? dragged.y : rect.y)
                    width: rect.w
                    z: space.front === modelData ? 2 : 1
                    front: space.front === modelData
                    shaded: GlanceState.shaded(modelData)
                    closable: modelData !== "empty"
                    shadeable: modelData !== "empty"
                    title: modelData === "empty" ? "Glance"
                        : isFleet && content && (shaded || content.summaryInTitle) ? content.titleText(Math.max(0, width - 80))
                        : Registry.label(modelData)
                    titleColor: isFleet && content && (shaded || content.summaryInTitle) ? content.toneColor(content.summaryTone) : Kit.PlatinumTokens.menuText
                    lightShape: isFleet && content && (shaded || content.summaryInTitle) ? content.lightShape : ""
                    lightTone: isFleet && content ? content.lightTone : "normal"
                    bodyHeight: content ? content.bodyHeight : 0

                    Component.onCompleted: { const m = Object.assign({}, space.items); m[modelData] = widget; space.items = m; }
                    Component.onDestruction: { const m = Object.assign({}, space.items); delete m[modelData]; space.items = m; }

                    onActivated: { if (space.front !== modelData) { space.front = modelData; } space.focusFront(); }
                    onCloseClicked: GlanceState.setEnabled(modelData, false)
                    onShadeClicked: GlanceState.setShaded(modelData, !shaded)
                    onDragged: function (dx, dy) {
                        if (space.plan.scroll) return;
                        const d = Object.assign({}, space.drag);
                        const at = d[modelData] || {x: rect.x, y: rect.y};
                        d[modelData] = {
                            x: Math.max(0, Math.min(space.spaceW - width, at.x + dx)),
                            y: Math.max(0, Math.min(space.spaceH - 18, at.y + dy))
                        };
                        space.drag = d;
                    }
                    onDragFinished: {
                        const at = space.drag[modelData];
                        if (!at) return;
                        const r = GlancePlan.remember(at.x, at.y, width, space.spaceW, space.plan.sb);
                        GlanceState.place(modelData, r.r, r.t);
                        const d = Object.assign({}, space.drag);
                        delete d[modelData];
                        space.drag = d;
                    }

                    Loader {
                        id: loader
                        width: widget.contentWidth
                        sourceComponent: widget.modelData === "fleet" ? fleetView
                            : widget.modelData === "disks" ? disksView : emptyView
                        onLoaded: {
                            item.frameChromeHeight = Qt.binding(function () { return widget.chromeHeight; });
                            item.maxFrameHeight = Qt.binding(function () { return widget.cap; });
                            if (widget.isFleet) {
                                item.frameWidth = Qt.binding(function () { return widget.width; });
                                item.frameChromeWidth = Qt.binding(function () { return widget.chromeWidth; });
                            }
                            item.escapePressed.connect(space.close);
                        }
                    }
                }
            }
        }

        PlatinumScrollBar {
            visible: space.plan.scroll && space.frame.widgets
            flickable: scroller
            x: space.spaceW - width
            y: space.barH
            height: space.spaceH
        }

        // The zoom rects: thin outlines, never faded; four trail each widget.
        Repeater {
            model: space.frame.outlines ? space.planIds : []
            Item {
                id: trail
                required property string modelData
                readonly property var w: space.items[modelData]
                readonly property var target: w ? {x: w.x, y: space.barH + w.y - scroller.contentY, w: w.width, h: w.height}
                    : ({x: 0, y: 0, w: 0, h: 0})
                Repeater {
                    model: space.frame.outlines || []
                    Item {
                        required property real modelData
                        readonly property var r: GlancePlan.between(space.origin, trail.target, modelData)
                        x: space.snap(r.x)
                        y: space.snap(r.y)
                        width: space.snap(Math.max(2 * Kit.PlatinumTokens.hairFor(QsWindow.window), r.w))
                        height: space.snap(Math.max(2 * Kit.PlatinumTokens.hairFor(QsWindow.window), r.h))
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: Kit.PlatinumTokens.hairFor(QsWindow.window)
                            border.color: PlatinumGlanceTokens.zoomOuter
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Kit.PlatinumTokens.hairFor(QsWindow.window)
                            color: "transparent"
                            border.width: Kit.PlatinumTokens.hairFor(QsWindow.window)
                            border.color: PlatinumGlanceTokens.zoomInner
                        }
                    }
                }
            }
        }
    }

    Component {
        id: fleetView
        PlatinumFleetView {
            panel: space.beszel
            focus: true
        }
    }
    Component {
        id: disksView
        PlatinumDisksWidget {
            panel: space.storage
        }
    }
    // Every widget turned off: the space says where they come back from.
    Component {
        id: emptyView
        FocusScope {
            id: empty
            property real frameHeight: -1
            property real maxFrameHeight: -1
            property real frameChromeHeight: 0
            signal escapePressed
            readonly property real naturalWidth: 300
            readonly property real restBodyHeight: column.implicitHeight + 26
            readonly property real bodyHeight: restBodyHeight
            Keys.onPressed: function (event) { if (event.key === Qt.Key_Escape) { empty.escapePressed(); event.accepted = true; } }
            Column {
                id: column
                x: 14
                y: 12
                width: parent.width - 28
                spacing: 10
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "No glance widgets are on"
                    color: Kit.PlatinumTokens.menuText
                    font.family: Kit.PlatinumTokens.platinumFont
                    font.pixelSize: Kit.PlatinumTokens.platinumText
                    font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                    text: "Choose them in the Glance menu: click the Fleet light in the menu bar."
                    color: Kit.PlatinumTokens.menuTextSecondary
                    font.family: Kit.PlatinumTokens.platinumFont
                    font.pixelSize: Kit.PlatinumTokens.platinumSmall
                    font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                }
                PlatinumButton {
                    visible: space.beszel !== null
                    text: "Show Fleet"
                    onClicked: GlanceState.setEnabled("fleet", true)
                }
            }
        }
    }
}
