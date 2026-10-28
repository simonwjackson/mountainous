pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "themes/win98/taskbar-plan.js" as Plan
import "themes/win98/tray-model.js" as Tray
import "app-icon.js" as AppIcon

// The Win98 taskbar: 28 u at the bottom edge, which it reserves.
//
//   [Start] [window][window] | [window] ... » | ‖ dictation | [» icons  4:51 PM]
//
// One band per page. Between two pages stands a divider: Win98's etched
// groove between toolbar groups (2 u), drawn only, with no button, hover,
// tooltip or number. A page is named by its apps (Start ▸ Windows, Move
// to), never numbered; a window button switches to its page.
// Window buttons carry the dock's behaviour: a click focuses, the middle
// button closes, a drag swaps two windows on one page or moves a window to
// another page (shell dropOnto). Layout is Plan.plan(width): readouts yield
// before controls, then windows and tray icons move into chevron menus.
//
// The surface is taller than the bar by `headroom`, transparent and outside
// the input mask, so key tips and the drag ghost can rise above the bar.
PanelWindow {
    id: bar

    required property var desktop
    screen: desktop.screen

    readonly property real u: Win98Tokens.unitFor(bar)
    readonly property real barHeight: 28 * u
    readonly property real headroom: 16 * u
    readonly property real faceY: face.y

    // A layer surface is a whole number of logical px tall, and 28 u is not
    // (37.3 at scale 1.5). The surface takes the next height whose physical
    // size is whole, and the bar sits on its bottom edge, so every bevel
    // line still lands on whole physical pixels. The zone rounds up.
    function wholeHeight(want) {
        const dpr = bar.devicePixelRatio > 0 ? bar.devicePixelRatio : (2 / bar.u);
        for (let k = Math.ceil(want - 1e-6); k < want + 16; k++)
            if (Math.abs(k * dpr - Math.round(k * dpr)) < 1e-4) return k;
        return Math.ceil(want);
    }
    anchors { bottom: true; left: true; right: true }
    implicitHeight: wholeHeight(barHeight + headroom)
    exclusiveZone: Math.ceil(barHeight - 1e-6)
    color: "transparent"
    WlrLayershell.namespace: "mountainous-taskbar"
    mask: Region { item: face }


    function units(n) { return n * bar.u; }
    // The bar's top edge in the screen's logical px (where context menus
    // rise from).
    readonly property real screenTop: (bar.screen ? bar.screen.height : bar.height) - bar.barHeight
    // A text's width for the plan, in units: one more than its whole
    // pixels, as the approved mock's canvas measured (a width just over a
    // whole pixel, rounded up). The plan yields at the mock's widths, and
    // every estimate errs one unit wide.
    function m(text, bold) { return Math.floor(Win98Tokens.textWidth(text, bold, bar.u) / bar.u + 1e-6) + 1; }

    readonly property var lane: bar.desktop.lane
    readonly property var dict: bar.desktop.dictation
    readonly property bool dictFailed: dict.barVisible && dict.state === "failed"

    readonly property var plan: Plan.plan(Math.round(width / u), {
        windows: lane.map(function (t) { return { page: bar.desktop.pageOf(t), focused: !!t.activated && !bar.desktop.isMinimized(t) }; }),
        showingPage: bar.desktop.showingPage,
        tray: bar.desktop.trayIds.map(function (id) { return { id: id, badge: bar.desktop.badge(id) }; }),
        clock: bar.desktop.clock,
        dict: { visible: dict.barVisible, failed: bar.dictFailed, canRetry: dict.canRetry, text: bar.desktop.dictText },
        extras: bar.desktop.taskExtras,
        measure: bar.m
    })

    // The window buttons' band, for the geometry checks.
    readonly property var tasksArea: ({ x: tasks.x, w: tasks.width })
    // The page dividers in bar coordinates, for the checks: { x, w } each.
    // They are drawn only, so they are not in places (no hit target).
    function dividers() {
        const out = [];
        let x = tasks.x;
        for (const g of bar.plan.groups) {
            if (g.divider) out.push({ x: x, w: bar.units(2) });
            x += bar.units(g.head) + g.windows.length * (bar.units(bar.plan.bw) + bar.units(3));
        }
        return out;
    }
    function overflowed(id) { return bar.plan.trayOut.indexOf(id) >= 0; }

    // Where each control is, in bar coordinates, for placing its window and
    // tooltip: { x, w }. Read through the item tree so it follows layout.
    property var places: ({})
    function placeOf(id) {
        const item = bar.places[id];
        if (!item || !item.visible) return null;
        const p = item.mapToItem(face, 0, 0);
        return { x: p.x, w: item.width };
    }
    function register(id, item) {
        const next = Object.assign({}, bar.places);
        next[id] = item;
        bar.places = next;
    }

    // ---- interaction state, with the preview override for state sheets
    readonly property var preview: bar.desktop.preview || ({})
    property string hoverId: ""
    // The Glance button's last press, for its double-click (the button is
    // rebuilt whenever the plan changes, so the time lives here).
    property double glancePressAt: 0
    property string pressId: ""
    function hovered(id) { return preview.hover === id || (bar.hoverId === id && !preview.hover); }
    function pressed(id) { return preview.press === id || bar.pressId === id; }
    function focused(id) { return preview.focus === id || bar.desktop.taskbarFocus === id; }
    function isOpen(id) { return bar.desktop.openId === id; }

    // Tooltips: half a second over a control, none while a menu is open.
    Timer {
        id: tipDelay
        interval: 500
        onTriggered: if (bar.hoverId !== "" && bar.desktop.openId === "") bar.desktop.tipId = bar.hoverId
    }
    function hoverIn(id) {
        bar.hoverId = id;
        bar.desktop.enter(id);
        bar.desktop.tipId = "";
        tipDelay.restart();
    }
    function hoverOut(id) {
        if (bar.hoverId === id) bar.hoverId = "";
        if (bar.desktop.tipId === id) bar.desktop.tipId = "";
    }

    // ---- drag: one owner for the gesture; buttons only read it.
    property int dragIndex: preview.drag ? 1 : -1
    property int dropIndex: preview.drag ? 3 : -1
    property real dragX: 0
    function buttonAt(x) {
        for (const id in bar.places) {
            if (id.indexOf("win") !== 0) continue;
            const item = bar.places[id];
            if (!item || !item.visible) continue;
            const p = item.mapToItem(face, 0, 0);
            if (x >= p.x - bar.units(3) && x < p.x + item.width) return Number(id.slice(3));
        }
        return -1;
    }

    Item {
        id: face
        y: bar.height - bar.barHeight
        width: bar.width
        height: bar.barHeight

        Rectangle { anchors.fill: parent; color: Win98Tokens.face }
        Rectangle { width: parent.width; height: bar.u; color: Win98Tokens.li }
        Rectangle { y: bar.u; width: parent.width; height: bar.u; color: Win98Tokens.hi }

        // A right click where no control takes it: the taskbar's own menu
        // (Minimize All, Minimize Other, Restore All, Find...), from the
        // pointer. Below every control, so their own buttons come first.
        MouseArea {
            objectName: "taskbarBackground"
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onPressed: function (mouse) {
                bar.desktop.tipId = "";
                bar.desktop.taskbarMenu(mouse.x, bar.screenTop);
            }
        }

        // ---- Start
        TaskButton {
            id: start
            x: bar.units(bar.plan.startX); y: bar.units(4)
            width: bar.units(bar.plan.startW)
            down: bar.isOpen("start") || bar.pressed("start")
            focusRing: bar.focused("start")
            iconName: "mark"
            label: bar.plan.startIcon ? "" : "Start"
            bold: true
            padLeft: 3; padRight: 5
            Component.onCompleted: bar.register("start", start)
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: bar.hoverIn("start")
                onExited: bar.hoverOut("start")
                onPressed: { bar.pressId = "start"; bar.desktop.tipId = ""; bar.desktop.press("start"); }
                onReleased: bar.pressId = ""
                onCanceled: bar.pressId = ""
            }
        }

        // ---- page bands and window buttons
        Item {
            id: tasks
            x: start.x + start.width
            y: bar.units(4)
            width: Math.max(0, (trayBox.visible ? trayBox.x - bar.units(3) : bar.width - bar.units(2))
                - (dictBand.visible ? dictBand.width : 0) - (extrasBand.visible ? extrasBand.width : 0) - x)
            height: bar.units(22)
            clip: true

            Row {
                id: bands
                height: parent.height

                Repeater {
                    // An empty bar has no bands: no grip, no empty slot.
                    model: bar.plan.groups

                    Item {
                        id: band
                        required property var modelData
                        readonly property int page: modelData.page
                        // The buttons start after the band's head: one gap after
                        // Start, or a divider and one gap (taskbar-plan.js).
                        readonly property real head: bar.units(modelData.head)
                        width: head + modelData.windows.length * (bar.units(bar.plan.bw) + bar.units(3))
                        height: bar.units(22)

                        // The divider between this page and the one before.
                        Etch { visible: band.modelData.divider; x: 0 }

                        Repeater {
                            model: band.modelData.windows

                            WindowButton {
                                required property int modelData
                                required property int index
                                index_: modelData
                                x: band.head + index * (bar.units(bar.plan.bw) + bar.units(3))
                            }
                        }
                    }
                }

                // The windows chevron.
                Chevron {
                    id: tasksChevron
                    cid: "tasks"
                    visible: bar.plan.tasksChevron
                    Component.onCompleted: bar.register("tasks", tasksChevron)
                }
            }
        }

        // ---- extras: a minimized Fleet window's button and the Glance
        // button, in their own band at the right end of the task area.
        Item {
            id: extrasBand
            visible: bar.plan.extras.length > 0
            x: (dictBand.visible ? dictBand.x : trayBox.visible ? trayBox.x - bar.units(3) : bar.width - bar.units(2)) - width
            y: bar.units(4)
            height: bar.units(22)
            width: bar.plan.boxes.extras ? bar.units(bar.plan.boxes.extras.w) : 0
            Etch { x: bar.units(2) }
            Grip { x: bar.units(7) }
            Row {
                x: bar.units(12)
                spacing: bar.units(3)
                Repeater {
                    model: bar.plan.extras
                    Loader {
                        required property string modelData
                        sourceComponent: modelData === "glance" ? glanceButton : fleetButton
                    }
                }
            }
        }
        Component {
            id: glanceButton
            TaskButton {
                id: gb
                objectName: "glanceButton"
                width: bar.units(bar.plan.extraW.glance || 26)
                // Pressed and lit while the space shows, as the active
                // window's button is.
                down: true
                dither: true
                bold: true
                iconName: "glance"
                label: bar.plan.icons || bar.plan.steps.indexOf("titles") >= 0 ? "" : "Glance"
                focusRing: bar.focused("glance")
                Component.onCompleted: bar.register("glance", gb)
                Component.onDestruction: if (bar.places.glance === gb) bar.register("glance", null)
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: bar.hoverIn("glance")
                    onExited: bar.hoverOut("glance")
                    // A click opens the Glance menu; a double-click runs its
                    // default item (Hide Glance), as Win98 ran the bold item.
                    onPressed: function (mouse) {
                        bar.desktop.tipId = "";
                        const now = Date.now();
                        if (mouse.button === Qt.LeftButton && now - bar.glancePressAt < 400) {
                            bar.glancePressAt = 0;
                            bar.desktop.closeMenu();
                            bar.desktop.hideGlance();
                            return;
                        }
                        bar.glancePressAt = mouse.button === Qt.LeftButton ? now : 0;
                        if (mouse.button === Qt.RightButton) bar.desktop.openMenu("glance", false);
                        else bar.desktop.press("glance");
                    }
                }
            }
        }
        Component {
            id: fleetButton
            TaskButton {
                id: fb
                objectName: "fleetButton"
                width: bar.units(bar.plan.extraW.fleet || 26)
                down: bar.pressed("fleetbutton")
                hostLook: bar.desktop.fleetLook
                label: bar.plan.icons || bar.plan.steps.indexOf("titles") >= 0 ? "" : bar.desktop.fleetButtonText
                labelColor: Win98Tokens.tone(bar.desktop.fleetLook.tone === "muted" ? "normal" : bar.desktop.fleetLook.tone)
                focusRing: bar.focused("fleetbutton")
                Component.onCompleted: bar.register("fleetbutton", fb)
                Component.onDestruction: if (bar.places.fleetbutton === fb) bar.register("fleetbutton", null)
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: bar.hoverIn("fleetbutton")
                    onExited: bar.hoverOut("fleetbutton")
                    onPressed: { bar.pressId = "fleetbutton"; bar.desktop.tipId = ""; }
                    onReleased: bar.pressId = ""
                    onCanceled: bar.pressId = ""
                    onClicked: bar.desktop.restoreFleet()
                }
            }
        }

        // ---- dictation: what the recorder is doing, and Retry / Dismiss
        Item {
            id: dictBand
            visible: bar.plan.dictShow
            x: trayBox.x - bar.units(3) - width
            y: bar.units(4)
            height: bar.units(22)
            width: bar.units(13) + (dictLabel.visible ? dictLabel.width + bar.units(4) : 0)
                + (retry.visible ? retry.width + bar.units(4) : 0) + (dismiss.visible ? dismiss.width + bar.units(4) : 0)
                + bar.units(2) - bar.units(4)
            Etch { x: bar.units(2) }
            Grip { x: bar.units(7) }
            Win98Text {
                id: dictLabel
                visible: bar.plan.dictTextShow
                x: bar.units(13)
                y: Win98Tokens.snap((parent.height - height) / 2, bar.u)
                text: bar.desktop.dictText
                accessMarks: false
                color: bar.dictFailed ? Win98Tokens.danger : Win98Tokens.text
            }
            Win98Button {
                id: retry
                visible: bar.dictFailed && bar.dict.canRetry
                small: true
                x: dictLabel.visible ? dictLabel.x + dictLabel.width + bar.units(4) : bar.units(13)
                y: bar.units(1)
                text: "&Retry"
                onClicked: bar.dict.retryFailed()
            }
            Win98Button {
                id: dismiss
                visible: bar.dictFailed
                small: true
                x: retry.visible ? retry.x + retry.width + bar.units(4) : dictLabel.visible ? dictLabel.x + dictLabel.width + bar.units(4) : bar.units(13)
                y: bar.units(1)
                text: "&Dismiss"
                onClicked: bar.dict.dismissFailure()
            }
        }

        // ---- the tray: icons, then the clock
        Item {
            id: trayBox
            visible: bar.plan.structure !== "start"
            readonly property real clockW: bar.plan.clockOut ? 0
                : bar.units(6 + 5) + Win98Tokens.ceilU(Win98Tokens.textWidth(bar.plan.clockText, false, bar.u), bar.u)
            x: bar.width - bar.units(2) - width
            y: bar.units(4)
            height: bar.units(22)
            width: bar.units(3) + (moreChevron.visible ? bar.units(14) : 0) + trayRow.width + clockW + bar.units(2)

            Win98Bevel { anchors.fill: parent; variant: "thinSunken"; filled: false }

            Chevron {
                id: moreChevron
                cid: "more"
                x: bar.units(3)
                visible: bar.plan.chevron
                Component.onCompleted: bar.register("more", moreChevron)
            }

            Row {
                id: trayRow
                x: bar.units(3) + (moreChevron.visible ? bar.units(14) : 0)
                y: bar.units(1)
                Repeater {
                    model: bar.plan.tray
                    TrayIcon {
                        required property string modelData
                        tid: modelData
                    }
                }
            }

            Item {
                id: clockItem
                visible: !bar.plan.clockOut
                x: trayRow.x + trayRow.width
                y: bar.units(1)
                width: trayBox.clockW
                height: bar.units(20)
                readonly property bool open: bar.isOpen("clock") || bar.pressed("clock")
                Component.onCompleted: bar.register("clock", clockItem)
                Win98Bevel {
                    anchors.fill: parent
                    filled: false
                    visible: clockItem.open || bar.hovered("clock")
                    variant: clockItem.open ? "thinSunken" : "thinRaised"
                }
                Win98Text {
                    x: bar.units(6)
                    y: Win98Tokens.snap((parent.height - height) / 2, bar.u)
                    text: bar.plan.clockText
                    accessMarks: false
                }
                Win98FocusRect {
                    visible: bar.focused("clock")
                    x: bar.u; y: bar.u
                    width: parent.width - 2 * bar.u; height: parent.height - 2 * bar.u
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: bar.hoverIn("clock")
                    onExited: bar.hoverOut("clock")
                    onPressed: { bar.pressId = "clock"; bar.desktop.tipId = ""; bar.desktop.press("clock"); }
                    onReleased: bar.pressId = ""
                    onCanceled: bar.pressId = ""
                }
            }
        }
    }

    // ---- the drag ghost and its insertion mark rise above the bar
    Item {
        id: ghost
        visible: bar.dragIndex >= 0 && bar.dropIndex >= 0 && bar.dropIndex !== bar.dragIndex
        readonly property var target: visible ? bar.placeOf("win" + bar.dropIndex) : null
        x: bar.preview.drag && target ? target.x + bar.units(7) : Win98Tokens.snap(bar.dragX - width / 2, bar.u)
        y: face.y + bar.units(4) - bar.units(14)
        width: bar.units(bar.plan.bw)
        height: bar.units(22)
        opacity: 0.85
        TaskButton {
            anchors.fill: parent
            down: false
            iconName: bar.dragIndex >= 0 ? (bar.desktop.winIcon(bar.lane[bar.dragIndex]) || "") : ""
            toplevel: bar.dragIndex >= 0 ? bar.lane[bar.dragIndex] : null
            label: bar.plan.icons || bar.dragIndex < 0 || !bar.lane[bar.dragIndex] ? "" : (bar.lane[bar.dragIndex].title || "")
            padLeft: 3; padRight: 4
        }
        Win98FocusRect {
            x: bar.units(4); y: bar.units(4)
            width: parent.width - bar.units(8); height: parent.height - bar.units(8)
        }
    }

    // ---- pieces
    component Etch: Item {
        y: bar.u
        width: bar.units(2); height: bar.units(20)
        Rectangle { width: bar.u; height: parent.height; color: Win98Tokens.sh }
        Rectangle { x: bar.u; width: bar.u; height: parent.height; color: Win98Tokens.hi }
    }
    component Grip: Win98Bevel {
        y: bar.u
        width: bar.units(3); height: bar.units(20)
        variant: "thinRaised"
        filled: false
    }

    // A taskbar button: raised at rest; pressed in (over the dither when
    // it is the focused window); icon, then the label, cut with dots.
    component TaskButton: Item {
        id: tb
        property bool down: false
        property bool lit: false
        property bool dither: false
        property bool focusRing: false
        property string iconName: ""
        property var toplevel: null
        // A Fleet host icon instead ({ status, tone }).
        property var hostLook: null
        property string label: ""
        property color labelColor: Win98Tokens.text
        property bool bold: false
        property real padLeft: 3
        property real padRight: 4
        height: bar.units(22)

        Rectangle { anchors.fill: parent; color: tb.lit ? Win98Tokens.selection : Win98Tokens.face }
        Win98Dither { visible: tb.dither && !tb.lit; anchors.fill: parent }
        Win98Bevel { anchors.fill: parent; filled: false; variant: tb.down ? "pressed" : "button" }
        Row {
            x: bar.units(tb.padLeft + (tb.down ? 1 : 0))
            y: tb.down ? bar.u : 0
            height: bar.units(tb.down ? 21 : 22)
            spacing: bar.units(3)
            Item {
                id: iconCell
                width: bar.units(16)
                height: parent.height
                Win98Icon {
                    visible: tb.iconName !== ""
                    name: tb.iconName
                    y: Win98Tokens.snap((iconCell.height - height) / 2, bar.u)
                }
                Win98HostIcon {
                    visible: tb.hostLook !== null
                    hostStatus: tb.hostLook ? tb.hostLook.status : "up"
                    tone: tb.hostLook ? tb.hostLook.tone : "normal"
                    y: Win98Tokens.snap((iconCell.height - height) / 2, bar.u)
                }
                IconImage {
                    visible: tb.iconName === "" && tb.hostLook === null && source !== ""
                    y: Win98Tokens.snap((iconCell.height - height) / 2, bar.u)
                    implicitSize: bar.units(16)
                    source: {
                        if (tb.iconName !== "" || tb.hostLook !== null || !tb.toplevel) return "";
                        const id = bar.desktop.appIdOf(tb.toplevel);
                        if (id === "") return "";
                        const e = DesktopEntries.heuristicLookup(id);
                        const name = AppIcon.themeName(id, e && e.icon ? e.icon : "");
                        return Quickshell.iconPath(name, AppIcon.fallback(name));
                    }
                }
            }
            Win98Text {
                visible: tb.label !== ""
                y: Win98Tokens.snap((parent.height - height) / 2, bar.u)
                width: Math.max(0, Math.min(implicitWidth, tb.width - bar.units(tb.padLeft + 16 + 3 + tb.padRight)))
                text: tb.label
                accessMarks: false
                bold: tb.bold
                color: tb.lit ? Win98Tokens.selectionText : tb.labelColor
            }
        }
        Win98FocusRect {
            visible: tb.focusRing
            x: bar.units(3); y: bar.units(3)
            width: tb.width - bar.units(6); height: tb.height - bar.units(6)
        }
    }

    component WindowButton: TaskButton {
        id: wb
        property int index_: 0
        readonly property var t: bar.lane[index_] || null
        readonly property string wid: "win" + index_
        // A minimized window keeps its button, raised (Win98).
        readonly property bool minimized: bar.desktop.isMinimized(t)
        readonly property bool activated: !!(t && t.activated) && !minimized
        readonly property bool urgent: !!(t && t.urgent) && !activated
        // Win98 flashed a window that wanted attention, then left it lit
        // until it was focused.
        property int flashes: 0
        onUrgentChanged: { flashes = 0; if (urgent) flash.restart(); else flash.stop(); }
        Timer {
            id: flash
            interval: 500
            repeat: true
            onTriggered: { wb.flashes++; if (wb.flashes >= 7) stop(); }
        }
        readonly property bool flashLit: urgent && (bar.preview.flash !== undefined
            ? bar.preview.flash === "on" : flashes >= 7 || flashes % 2 === 0)
        width: bar.units(bar.plan.bw)
        down: activated || bar.pressed(wid)
        dither: activated
        lit: flashLit && !activated
        bold: activated
        focusRing: bar.focused(wid)
        iconName: bar.desktop.winIcon(t)
        toplevel: t
        label: bar.plan.icons ? "" : (t ? (t.title || "(untitled)") : "")
        opacity: bar.dragIndex === index_ && ghost.visible ? 0.4 : 1
        Component.onCompleted: bar.register(wid, wb)
        Component.onDestruction: if (bar.places[wid] === wb) bar.register(wid, null)

        // The insertion mark, in the gap before the drop target.
        Item {
            visible: ghost.visible && bar.dropIndex === wb.index_
            x: -bar.units(3)
            width: bar.units(2); height: parent.height
            z: 2
            Rectangle { anchors.fill: parent; color: Win98Tokens.text }
            Rectangle { x: -bar.units(2); width: bar.units(6); height: bar.units(2); color: Win98Tokens.text }
            Rectangle { x: -bar.units(2); y: parent.height - bar.units(2); width: bar.units(6); height: bar.units(2); color: Win98Tokens.text }
        }

        MouseArea {
            id: grip
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            // A click and a drag start alike; a drag needs travel.
            readonly property real threshold: bar.units(6)
            property real pressX: 0
            property bool dragging: false
            onEntered: bar.hoverIn(wb.wid)
            onExited: bar.hoverOut(wb.wid)
            onPressed: function (mouse) {
                grip.pressX = mouse.x;
                grip.dragging = false;
                bar.desktop.tipId = "";
                if (mouse.button === Qt.LeftButton) bar.pressId = wb.wid;
                // The right button: the window menu, from the pointer.
                if (mouse.button === Qt.RightButton) {
                    const p = grip.mapToItem(face, mouse.x, mouse.y);
                    bar.desktop.windowMenu(bar.desktop.addressOf(wb.t), p.x, bar.screenTop);
                }
            }
            onPositionChanged: function (mouse) {
                if (!(mouse.buttons & Qt.LeftButton)) return;
                if (!grip.dragging && Math.abs(mouse.x - grip.pressX) < grip.threshold) return;
                grip.dragging = true;
                bar.pressId = "";
                const p = grip.mapToItem(face, mouse.x, mouse.y);
                bar.dragX = p.x;
                bar.dragIndex = wb.index_;
                bar.dropIndex = bar.buttonAt(p.x);
            }
            onReleased: function (mouse) {
                bar.pressId = "";
                if (!grip.dragging) return;
                bar.desktop.shell.dropOnto(bar.lane, wb.index_, bar.dropIndex);
                bar.dragIndex = -1;
                bar.dropIndex = -1;
            }
            // A release after a drag still clicks; activating then would
            // undo the move by pulling focus to the old page.
            onClicked: function (mouse) {
                if (grip.dragging) { grip.dragging = false; return; }
                if (mouse.button === Qt.RightButton) return;
                if (mouse.button === Qt.MiddleButton) { bar.desktop.closeWindow(wb.t); return; }
                // Over the glance space a window button dismisses it, then
                // switches; the active window's button minimizes it, a
                // minimized one's restores it.
                const glance = bar.desktop.fleetGlance.glanceShown;
                bar.desktop.hideGlance();
                if (glance && !wb.minimized) bar.desktop.activateWindow(wb.t);
                else bar.desktop.clickWindow(wb.t);
            }
            onCanceled: {
                grip.dragging = false;
                bar.pressId = "";
                bar.dragIndex = -1;
                bar.dropIndex = -1;
            }
        }
    }

    component Chevron: Item {
        id: ch
        property string cid: ""
        readonly property bool sunk: bar.isOpen(cid) || bar.pressed(cid)
        width: bar.units(12); height: bar.units(22)
        Win98Bevel {
            anchors.fill: parent
            filled: false
            visible: ch.sunk || bar.hovered(ch.cid)
            variant: ch.sunk ? "thinSunken" : "thinRaised"
        }
        Win98Icon {
            name: "chevron"
            x: Win98Tokens.half((ch.width - width) / 2, bar.u)
            y: Win98Tokens.snap((ch.height - height) / 2, bar.u)
        }
        Win98FocusRect {
            visible: bar.focused(ch.cid)
            x: bar.units(2); y: bar.units(2)
            width: ch.width - bar.units(4); height: ch.height - bar.units(4)
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: bar.hoverIn(ch.cid)
            onExited: bar.hoverOut(ch.cid)
            onPressed: { bar.pressId = ch.cid; bar.desktop.tipId = ""; bar.desktop.press(ch.cid); }
            onReleased: bar.pressId = ""
            onCanceled: bar.pressId = ""
        }
    }

    // A tray icon: flat; a thin raised edge on hover, sunken while its
    // window is open or the pointer holds it; latched over the dither.
    component TrayIcon: Item {
        id: ti
        property string tid: ""
        readonly property string badge: bar.desktop.badge(tid)
        readonly property bool open: bar.isOpen(tid) || bar.pressed(tid)
        readonly property bool latched: tid === "builder" && bar.desktop.builderLook.latched && !open
        width: bar.units(Plan.trayWidth(badge))
        height: bar.units(20)
        Component.onCompleted: bar.register(ti.tid, ti)
        Component.onDestruction: if (bar.places[ti.tid] === ti) bar.register(ti.tid, null)

        Win98Dither { visible: ti.latched; anchors.fill: parent }
        Win98Bevel {
            anchors.fill: parent
            filled: false
            visible: ti.open || ti.latched || bar.hovered(ti.tid)
            variant: ti.open || ti.latched ? "thinSunken" : "thinRaised"
        }
        Win98HostIcon {
            visible: ti.tid === "fleet"
            hostStatus: bar.desktop.fleetLook.status
            tone: bar.desktop.fleetLook.tone
            x: bar.units(2); y: bar.units(2)
        }
        Win98Icon {
            visible: ti.tid !== "fleet"
            name: ti.tid === "fleet" ? "" : bar.desktop.trayIcon(ti.tid)
            level: ti.tid === "bat" ? Math.max(0, Math.min(1, bar.desktop.battery.percent / 100)) : undefined
            levelColor: Tray.batteryColor(bar.desktop.batteryRule.tone)
            x: bar.units(2); y: bar.units(2)
        }
        Win98Badge {
            visible: ti.badge !== ""
            anchors.right: parent.right
            anchors.top: parent.top
            text: ti.badge
        }
        // Super+O: the key that opens this control.
        Rectangle {
            visible: bar.desktop.shell.chromeAccessVisible && Tray.CHORD[ti.tid] !== undefined
            x: bar.units(5); y: -bar.units(14)
            width: bar.units(9); height: bar.units(11)
            color: Win98Tokens.tip
            border.width: bar.u
            border.color: Win98Tokens.dk
            Win98Text {
                x: Win98Tokens.half((parent.width - width) / 2, bar.u)
                y: -bar.u
                text: Tray.CHORD[ti.tid] || ""
                accessMarks: false
                color: Win98Tokens.tipText
            }
        }
        Win98FocusRect {
            visible: bar.focused(ti.tid)
            x: bar.u; y: bar.u
            width: ti.width - 2 * bar.u; height: ti.height - 2 * bar.u
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            // The Fleet icon's right button opens its menu (Win98's tray
            // context menu): Open Fleet, Show Glance.
            acceptedButtons: ti.tid === "fleet" ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
            onEntered: bar.hoverIn(ti.tid)
            onExited: bar.hoverOut(ti.tid)
            onPressed: function (mouse) {
                bar.pressId = ti.tid;
                bar.desktop.tipId = "";
                if (ti.tid === "fleet" && mouse.button === Qt.RightButton) bar.desktop.openMenu("fleetmenu", false);
                else if (ti.tid !== "bat") bar.desktop.press(ti.tid);
            }
            onReleased: bar.pressId = ""
            onCanceled: bar.pressId = ""
        }
    }
}
