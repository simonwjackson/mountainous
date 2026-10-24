import Quickshell
import Quickshell.Wayland
import QtQuick

// The standalone Fleet windoid: a Platinum utility window at the top right
// under the bar, where the Disks and Cloud menus drop. Super+B toggles it,
// and so does Super+O then F. It floats beside the work with no veil and
// takes keyboard focus only when clicked, so summoning it never steals
// typing. Drag the title bar to move it and the grow box to resize it;
// both are remembered (GlanceState). WindowShade rolls it up to its title.
PanelWindow {
    id: win

    required property var desktop
    required property var panel

    readonly property bool wanted: desktop.active && GlanceState.fleetScreen === desktop.screen
    screen: desktop.screen
    visible: wanted

    // The saved place and size, with a drag in progress laid over it (the
    // state file is written once, when the drag ends).
    property var live: ({})
    readonly property var saved: Object.assign({}, GlanceState.saved.fleet, live)
    readonly property real screenW: screen ? screen.width : 1920
    readonly property real screenH: screen ? screen.height : 1200
    readonly property real topOffset: PlatinumTokens.barHeight + (saved.t !== undefined ? saved.t : 6)
    // Room below: the dock's 44 px and its margins stay clear.
    readonly property real availH: Math.max(windoid.chromeHeight + 40, screenH - topOffset - 58)
    readonly property real frameW: Math.max(150, Math.min(saved.w !== undefined ? saved.w : view.naturalWidth, screenW - 8))
    readonly property real frameH: saved.h !== undefined ? Math.max(93, Math.min(saved.h, availH))
        : -1

    anchors { top: true; right: true }
    margins {
        top: Math.max(PlatinumTokens.barHeight, Math.min(win.topOffset, win.screenH - 20))
        right: Math.max(0, Math.min(saved.r !== undefined ? saved.r : 8, win.screenW - win.frameW))
    }
    implicitWidth: Math.ceil(frameW + PlatinumTokens.hair)
    implicitHeight: Math.ceil(windoid.height + PlatinumTokens.hair)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "mountainous-fleet"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    function close() { GlanceState.hideFleet(); }
    function commit() {
        if (Object.keys(win.live).length) GlanceState.setFleet(win.live);
        win.live = {};
    }

    PlatinumWindoid {
        id: windoid
        width: win.frameW
        shaded: win.saved.shaded === true
        title: shaded || view.summaryInTitle ? view.titleText(Math.max(0, width - 80)) : "Fleet"
        titleColor: shaded || view.summaryInTitle ? view.toneColor(view.summaryTone) : PlatinumTokens.menuText
        lightShape: shaded || view.summaryInTitle ? view.lightShape : ""
        lightTone: view.lightTone
        front: true
        bodyHeight: view.bodyHeight
        onCloseClicked: win.close()
        onShadeClicked: GlanceState.setFleet({shaded: !shaded})
        onDragged: function (dx, dy) {
            const r = win.margins.right - dx;
            const t = win.margins.top + dy - PlatinumTokens.barHeight;
            win.live = Object.assign({}, win.live, {r: Math.round(Math.max(0, r)), t: Math.round(Math.max(0, t))});
        }
        onDragFinished: win.commit()

        PlatinumFleetView {
            id: view
            width: windoid.contentWidth
            panel: win.panel
            focus: true
            frameWidth: windoid.width
            frameHeight: win.frameH
            maxFrameHeight: win.availH
            frameChromeWidth: windoid.chromeWidth
            frameChromeHeight: windoid.chromeHeight
            growable: true
            onEscapePressed: win.close()
            onGrown: function (dx, dy) {
                const w = Math.max(150, Math.round(windoid.width + dx));
                const h = Math.max(93, Math.round((win.frameH >= 0 ? win.frameH : windoid.height) + dy));
                win.live = Object.assign({}, win.live, {w: w, h: h, r: Math.round(Math.max(0, win.margins.right - (w - windoid.width)))});
            }
            onGrowFinished: win.commit()
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: win.close()
    }
}
