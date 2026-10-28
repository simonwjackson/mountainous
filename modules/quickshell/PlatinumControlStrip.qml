import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "themes/platinum/strip-plan.js" as StripPlan
import "lanes.js" as Lanes

// The Mac OS 8 Control Strip, in place of the dock: every window on this
// screen across all its pages, as tiles at the bottom left.
//
//   click          switch to the window (its page comes with it)
//   middle-click   close it
//   drag           onto a tile on the same page: swap; another page: move
//   ▴ / right-click  the tile's menu (opens upward, cascades)
//   cap / tab      collapse; the tab expands, and dragging it sets the length
//   ◂ ▸ / wheel    scroll when the windows do not fit
//
// The window reserves a full-width band, 36 + 6 px, and keeps it when the
// strip collapses, so windows never resize on a click. The surface is
// taller than the band so a drag's label can show above the tiles; only
// the strip itself takes input.
PanelWindow {
    id: strip

    required property var modelData
    required property var shell
    required property var owner
    screen: modelData

    anchors { bottom: true; left: true; right: true }
    implicitHeight: StripPlan.BAND + 52
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: StripPlan.BAND
    color: "transparent"
    mask: Region { item: body }

    readonly property real hair: PlatinumTokens.hair
    readonly property bool bevelled: PlatinumTokens.stripBevelled
    readonly property string screenName: modelData ? modelData.name : ""

    // ------------------------------------------------------------ model
    readonly property var toplevels: strip.shell.windowsOn(strip.modelData)
    readonly property var rows: {
        const rowOf = strip.shell.rowOf;
        return StripPlan.order(strip.toplevels.map(function (t) {
            return typeof rowOf === "function" ? rowOf(t) : { page: Lanes.pageOf(t), toplevel: t, address: "", appId: "", title: t.title || "" };
        }));
    }
    readonly property var lane: rows.map(function (r) { return r.toplevel; })
    readonly property var layout: StripPlan.slots(rows)
    readonly property real emptyWidth: PlatinumMetrics.smallWidth("No windows") + 20
    readonly property var plan: StripPlan.plan(strip.width, layout.content, saved.length, emptyWidth)

    // ------------------------------------------------------------ saved state
    // $XDG_STATE_HOME/mountainous/control-strip.json, per screen.
    property var savedAll: ({})
    readonly property var saved: StripPlan.screenState(savedAll, strip.screenName)
    readonly property bool collapsed: saved.collapsed
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/mountainous"
    FileView {
        id: stateFile
        path: strip.stateDir + "/control-strip.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onLoaded: strip.savedAll = StripPlan.parseState(stateFile.text())
    }
    function store(entry) {
        strip.savedAll = StripPlan.withScreen(strip.savedAll, strip.screenName, entry);
        stateFile.setText(JSON.stringify(strip.savedAll) + "\n");
    }
    function setCollapsed(value) { strip.store({ collapsed: value, length: strip.saved.length }); }
    function setLength(value) { strip.store({ collapsed: false, length: value }); }

    // ------------------------------------------------------------ scrolling
    property real scroll: 0
    readonly property real shownScroll: StripPlan.clampScroll(scroll, plan.maxScroll)
    function slotOf(index) {
        for (const s of strip.layout.slots) if (s.kind === "tile" && s.index === index) return s;
        return null;
    }
    function reveal(index) {
        strip.scroll = StripPlan.scrollToShow(strip.slotOf(index), strip.shownScroll, strip.plan.area, strip.plan.maxScroll);
    }
    // Keep the focused window in view when focus moves along the strip.
    readonly property int focusedIndex: strip.lane.findIndex(function (t) { return t && t.activated; })
    onFocusedIndexChanged: if (focusedIndex >= 0) Qt.callLater(strip.reveal, focusedIndex)

    // ------------------------------------------------------------ places
    // Each tile in the screen's logical px, by window address: where the
    // window motion's zoom rects start and end (PlatinumMotionLayer). A
    // tile scrolled out of the track stands at its nearer end; a collapsed
    // strip's tiles at its tab. tail: where the next tile goes.
    readonly property real screenTop: (strip.modelData ? strip.modelData.height : strip.height) - strip.height + body.y
    readonly property var tiles: {
        const out = {};
        const y = strip.screenTop + PlatinumTokens.snap((StripPlan.HEIGHT - 30) / 2);
        for (const s of strip.layout.slots) {
            if (s.kind !== "tile") continue;
            const r = strip.rows[s.index];
            if (!r || !r.address) continue;
            if (strip.collapsed) { out[r.address] = { x: 0, y: strip.screenTop, w: StripPlan.TAB, h: StripPlan.HEIGHT }; continue; }
            const x = track.x + s.x - strip.shownScroll;
            out[r.address] = { x: Math.max(track.x, Math.min(track.x + track.width - 30, x)), y: y, w: 30, h: 30 };
        }
        return out;
    }
    readonly property var tail: strip.collapsed ? { x: 0, y: strip.screenTop, w: StripPlan.TAB, h: StripPlan.HEIGHT }
        : { x: Math.max(track.x, Math.min(track.x + track.width - 30, track.x + strip.layout.content - strip.shownScroll)),
            y: strip.screenTop + PlatinumTokens.snap((StripPlan.HEIGHT - 30) / 2), w: 30, h: 30 }

    // ------------------------------------------------------------ drag
    property int dragFrom: -1
    property int dragOver: -1
    property point dragAt: Qt.point(0, 0)
    readonly property var dropInfo: StripPlan.drop(strip.rows, strip.dragFrom, strip.dragOver, strip.owner.appNames)
    function tileAt(x, y) {
        const p = track.mapFromItem(strip.contentItem, x, y);
        const item = inner.childAt(p.x + strip.shownScroll, inner.height / 2);
        if (p.y < -8 || p.y > track.height + 8 || p.x < 0 || p.x > track.width) return -1;
        return item && item.tileIndex !== undefined ? item.tileIndex : -1;
    }

    // ------------------------------------------------------------ drawing
    Item {
        id: body
        x: 0
        y: strip.height - StripPlan.BOTTOM - StripPlan.HEIGHT
        width: strip.collapsed ? StripPlan.TAB : strip.plan.total
        height: StripPlan.HEIGHT

        // The strip's own surface, with its black top and bottom edges.
        Rectangle {
            visible: !strip.collapsed
            width: parent.width - StripPlan.TAB
            height: parent.height
            color: PlatinumTokens.stripSurface
            Rectangle { width: parent.width; height: strip.hair; color: PlatinumTokens.stripEdge }
            Rectangle { y: parent.height - strip.hair; width: parent.width; height: strip.hair; color: PlatinumTokens.stripEdge }
        }

        // The cap: collapses the strip.
        Item {
            id: cap
            visible: !strip.collapsed
            width: StripPlan.CAP
            height: parent.height
            Bevelled { anchors.fill: parent; pressed: capArea.pressed; rightEdge: true }
            Ridges { count: 2; anchors.centerIn: parent }
            MouseArea {
                id: capArea
                anchors.fill: parent
                onClicked: strip.setCollapsed(true)
            }
        }

        // ◂
        Item {
            id: leftArrow
            visible: !strip.collapsed && strip.plan.arrows
            x: StripPlan.CAP
            width: StripPlan.ARROW
            height: parent.height
            Bevelled { anchors.fill: parent; pressed: leftArea.pressed; rightEdge: true }
            PlatinumIcon {
                anchors.centerIn: parent
                width: 6; height: 9
                name: "scroll-left"
                color: strip.shownScroll <= 0 ? PlatinumTokens.barTextOff : PlatinumTokens.barText
            }
            MouseArea {
                id: leftArea
                anchors.fill: parent
                onClicked: strip.scroll = StripPlan.scrollStep(strip.layout.slots, strip.shownScroll, -1, strip.plan.maxScroll)
            }
        }

        // The track of tiles.
        Item {
            id: track
            visible: !strip.collapsed
            x: StripPlan.CAP + (strip.plan.arrows ? StripPlan.ARROW : 0)
            width: strip.plan.area
            height: parent.height
            clip: true

            // The track's own bevel: a light hair on top, a dark one below.
            Rectangle { visible: strip.bevelled; y: strip.hair; width: parent.width; height: strip.hair; color: PlatinumTokens.bevelLight }
            Rectangle { visible: strip.bevelled; y: parent.height - 2 * strip.hair; width: parent.width; height: strip.hair; color: PlatinumTokens.bevelDark }

            Text {
                visible: strip.plan.empty
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: "No windows"
                color: PlatinumTokens.barTextOff
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }

            Item {
                id: inner
                x: -strip.shownScroll
                width: Math.max(strip.layout.content, 1)
                height: parent.height
                Behavior on x {
                    enabled: !PlatinumTokens.reducedMotion
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }

                Repeater {
                    model: strip.layout.slots

                    Item {
                        id: slot
                        required property var modelData
                        readonly property bool isTile: modelData.kind === "tile"
                        readonly property int tileIndex: isTile ? modelData.index : -1
                        readonly property var row: isTile ? strip.rows[modelData.index] : null
                        x: PlatinumTokens.snap(modelData.x)
                        y: PlatinumTokens.snap((parent.height - 30) / 2)
                        width: modelData.w
                        height: 30

                        // The engraved groove between two pages.
                        Item {
                            visible: !slot.isTile
                            anchors.fill: parent
                            Rectangle {
                                x: PlatinumTokens.snap((parent.width - 2 * strip.hair) / 2)
                                y: 4; width: strip.hair; height: 22
                                color: PlatinumTokens.grooveLow
                            }
                            Rectangle {
                                x: PlatinumTokens.snap((parent.width - 2 * strip.hair) / 2) + strip.hair
                                y: 4; width: strip.hair; height: 22
                                color: PlatinumTokens.grooveHigh
                            }
                        }

                        PlatinumStripTile {
                            visible: slot.isTile
                            icon: slot.row ? strip.owner.appIcon(slot.row.appId) : ""
                            letter: slot.row ? (slot.row.title || "?").charAt(0).toUpperCase() : ""
                            shown: slot.row ? Lanes.isShown(slot.row.toplevel) : false
                            focused: slot.row && slot.row.toplevel ? slot.row.toplevel.activated : false
                            menuOpen: slot.row !== null && strip.owner.stripMenuOpen(strip.modelData, slot.row.address)
                            source: strip.dragFrom === slot.tileIndex && slot.isTile
                            target: strip.dragOver === slot.tileIndex && strip.dragFrom >= 0 && strip.dragFrom !== slot.tileIndex && slot.isTile

                            MouseArea {
                                id: grip
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                readonly property int threshold: 8
                                property real pressX: 0
                                property bool dragging: false
                                // The ▴ corner: 13 x 15 at the bottom right.
                                function onPop(mx, my) { return mx >= width - 13 && my >= height - 15; }

                                onPressed: function (mouse) {
                                    grip.pressX = mouse.x;
                                    grip.dragging = false;
                                }
                                onPositionChanged: function (mouse) {
                                    if (!(mouse.buttons & Qt.LeftButton)) return;
                                    if (!grip.dragging && Math.abs(mouse.x - grip.pressX) < grip.threshold) return;
                                    grip.dragging = true;
                                    const p = grip.mapToItem(strip.contentItem, mouse.x, mouse.y);
                                    strip.dragFrom = slot.tileIndex;
                                    strip.dragAt = Qt.point(p.x, p.y);
                                    strip.dragOver = strip.tileAt(p.x, p.y);
                                }
                                onReleased: function (mouse) {
                                    if (!grip.dragging) return;
                                    const p = grip.mapToItem(strip.contentItem, mouse.x, mouse.y);
                                    const to = strip.tileAt(p.x, p.y);
                                    strip.owner.dropTile(strip.lane, slot.tileIndex, to);
                                    strip.dragFrom = -1;
                                    strip.dragOver = -1;
                                }
                                onCanceled: { grip.dragging = false; strip.dragFrom = -1; strip.dragOver = -1; }
                                // A release after a drag still emits clicked;
                                // activating there would undo the drop.
                                onClicked: function (mouse) {
                                    if (grip.dragging) { grip.dragging = false; return; }
                                    if (!slot.row) return;
                                    if (mouse.button === Qt.MiddleButton) { strip.shell.closeWindow(slot.row.address); return; }
                                    if (mouse.button === Qt.RightButton || grip.onPop(mouse.x, mouse.y)) {
                                        const g = slot.mapToItem(strip.contentItem, 0, 0);
                                        // The menu window covers the screen; this window
                                        // is its bottom strip.
                                        const top = (strip.modelData ? strip.modelData.height : strip.height) - strip.height;
                                        strip.owner.openStripMenu(strip.modelData, slot.row.address, g.x, top + g.y - 6);
                                        return;
                                    }
                                    strip.owner.activateWindow(slot.row.address);
                                }
                            }
                        }
                    }
                }
            }

            WheelHandler {
                onWheel: function (event) {
                    const d = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
                    if (d !== 0) strip.scroll = StripPlan.scrollStep(strip.layout.slots, strip.shownScroll, d < 0 ? 1 : -1, strip.plan.maxScroll);
                }
            }
        }

        // ▸
        Item {
            visible: !strip.collapsed && strip.plan.arrows
            x: track.x + track.width
            width: StripPlan.ARROW
            height: parent.height
            Bevelled { anchors.fill: parent; pressed: rightArea.pressed; leftEdge: true }
            PlatinumIcon {
                anchors.centerIn: parent
                width: 6; height: 9
                name: "scroll-right"
                color: strip.shownScroll >= strip.plan.maxScroll ? PlatinumTokens.barTextOff : PlatinumTokens.barText
            }
            MouseArea {
                id: rightArea
                anchors.fill: parent
                onClicked: strip.scroll = StripPlan.scrollStep(strip.layout.slots, strip.shownScroll, 1, strip.plan.maxScroll)
            }
        }

        // The tab: click to collapse or expand; drag to set the length.
        Item {
            id: tab
            x: strip.collapsed ? 0 : body.width - StripPlan.TAB
            width: StripPlan.TAB
            height: parent.height

            // The rounded end, edged in black, with the bevel inside.
            Rectangle {
                anchors.fill: parent
                radius: 9
                color: tabArea.pressed && !tabArea.resizing ? PlatinumTokens.tileSunk : PlatinumTokens.stripSurface
                border.width: strip.hair
                border.color: PlatinumTokens.stripEdge
                // Square off the left side, which meets the strip.
                Rectangle {
                    width: parent.width / 2
                    height: parent.height
                    color: parent.color
                    Rectangle { width: parent.width; height: strip.hair; color: PlatinumTokens.stripEdge }
                    Rectangle { y: parent.height - strip.hair; width: parent.width; height: strip.hair; color: PlatinumTokens.stripEdge }
                    Rectangle { visible: strip.collapsed; width: strip.hair; height: parent.height; color: PlatinumTokens.stripEdge }
                    Rectangle { visible: !strip.collapsed; width: strip.hair; height: parent.height; color: PlatinumTokens.stripEdge }
                }
                Rectangle {
                    visible: strip.bevelled
                    x: strip.hair * 2; y: strip.hair
                    width: parent.width - 9 - x; height: strip.hair
                    color: tabArea.pressed && !tabArea.resizing ? PlatinumTokens.bevelDark : PlatinumTokens.bevelLight
                }
                Rectangle {
                    visible: strip.bevelled
                    x: strip.hair * 2; y: parent.height - 2 * strip.hair
                    width: parent.width - 9 - x; height: strip.hair
                    color: tabArea.pressed && !tabArea.resizing ? PlatinumTokens.bevelLight : PlatinumTokens.bevelDark
                }
            }
            Ridges { count: 3; anchors.centerIn: parent; anchors.horizontalCenterOffset: -1 }

            MouseArea {
                id: tabArea
                anchors.fill: parent
                cursorShape: strip.collapsed ? Qt.ArrowCursor : Qt.SizeHorCursor
                property real pressX: 0
                property real startArea: 0
                property bool resizing: false
                onPressed: function (mouse) {
                    tabArea.pressX = tabArea.mapToItem(strip.contentItem, mouse.x, 0).x;
                    tabArea.startArea = strip.plan.area;
                    tabArea.resizing = false;
                }
                onPositionChanged: function (mouse) {
                    if (strip.collapsed || !(mouse.buttons & Qt.LeftButton) || strip.plan.empty) return;
                    const dx = tabArea.mapToItem(strip.contentItem, mouse.x, 0).x - tabArea.pressX;
                    if (!tabArea.resizing && Math.abs(dx) < 6) return;
                    tabArea.resizing = true;
                    const next = StripPlan.dragLength(tabArea.startArea, dx, strip.layout.content);
                    if (next !== strip.saved.length) strip.setLength(next);
                }
                onReleased: function () {
                    if (tabArea.resizing) { tabArea.resizing = false; return; }
                    strip.setCollapsed(!strip.collapsed);
                }
                onCanceled: tabArea.resizing = false
            }
        }
    }

    // ------------------------------------------------------------ drag feedback
    // A dotted ghost follows the pointer; the target names what a drop does.
    Rectangle {
        visible: strip.dragFrom >= 0
        x: strip.dragAt.x - 15
        y: Math.min(strip.dragAt.y - 15, strip.height - 30)
        width: 30; height: 30
        color: "transparent"
        border.width: strip.hair
        border.color: PlatinumTokens.barText
        opacity: 0.9
        PlatinumAppIcon {
            anchors.centerIn: parent
            size: 20
            name: strip.dragFrom >= 0 && strip.rows[strip.dragFrom] ? strip.owner.appIcon(strip.rows[strip.dragFrom].appId) : ""
        }
    }
    Rectangle {
        id: dropLabel
        visible: strip.dragFrom >= 0 && strip.dropInfo.label !== ""
        readonly property var targetSlot: strip.slotOf(strip.dragOver)
        readonly property real targetX: targetSlot ? track.x + targetSlot.x - strip.shownScroll + 15 : 0
        x: Math.max(2, Math.min(targetX - width / 2, strip.width - width - 2))
        y: body.y + 3 - 30
        width: dropText.implicitWidth + 16
        height: dropText.implicitHeight + 6
        color: PlatinumTokens.menuSurface
        border.width: strip.hair
        border.color: PlatinumTokens.menuEdge
        Rectangle {
            z: -1
            x: 2 * strip.hair; y: 2 * strip.hair
            width: parent.width; height: parent.height
            color: PlatinumTokens.menuShadow
        }
        Text {
            id: dropText
            anchors.centerIn: parent
            text: strip.dropInfo.label
            color: PlatinumTokens.menuText
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumSmall
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
    }

    // ------------------------------------------------------------ parts
    // A raised end piece (cap, arrow): light hair on top, dark at the bottom
    // and on the side away from the track; pressed, it sinks.
    component Bevelled: Item {
        property bool pressed: false
        property bool rightEdge: false
        property bool leftEdge: false
        Rectangle {
            anchors.fill: parent
            color: parent.pressed ? PlatinumTokens.tileSunk : PlatinumTokens.stripSurface
        }
        Rectangle { visible: strip.bevelled; y: strip.hair; width: parent.width; height: strip.hair
            color: parent.pressed ? PlatinumTokens.bevelDark : PlatinumTokens.bevelLight }
        Rectangle { visible: strip.bevelled && parent.leftEdge; x: strip.hair; y: strip.hair; width: strip.hair; height: parent.height - 2 * strip.hair
            color: parent.pressed ? PlatinumTokens.bevelDark : PlatinumTokens.bevelLight }
        Rectangle { visible: strip.bevelled; y: parent.height - 2 * strip.hair; width: parent.width; height: strip.hair
            color: parent.pressed ? PlatinumTokens.bevelLight : PlatinumTokens.bevelDark }
        Rectangle { visible: strip.bevelled && parent.rightEdge; x: parent.width - 2 * strip.hair; y: strip.hair; width: strip.hair; height: parent.height - 2 * strip.hair
            color: parent.pressed ? PlatinumTokens.bevelLight : PlatinumTokens.bevelDark }
        // The black edge between this piece and the track.
        Rectangle { visible: parent.rightEdge; x: parent.width - strip.hair; width: strip.hair; height: parent.height; color: PlatinumTokens.stripEdge }
        Rectangle { visible: parent.leftEdge; width: strip.hair; height: parent.height; color: PlatinumTokens.stripEdge }
        Rectangle { width: parent.width; height: strip.hair; color: PlatinumTokens.stripEdge }
        Rectangle { y: parent.height - strip.hair; width: parent.width; height: strip.hair; color: PlatinumTokens.stripEdge }
    }

    // The grip ridges on the cap and the tab: dark hair, light hair beside.
    component Ridges: Row {
        property int count: 2
        spacing: strip.hair
        height: StripPlan.HEIGHT - 18
        Repeater {
            model: parent.count
            Row {
                height: parent.height
                Rectangle { width: strip.hair; height: parent.height; color: PlatinumTokens.ridgeLow }
                Rectangle { width: strip.hair; height: parent.height; color: PlatinumTokens.ridgeHigh }
            }
        }
    }
}
