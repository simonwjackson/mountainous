pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "beszel-model.js" as Model
import "themes/win98/fleet-plan.js" as Plan
import "themes/win98/host-icon.js" as HostIcon

// The standalone Fleet window (Super+B, Super+O F, the tray's Fleet icon):
// a Win98 window above the tray at the bottom right, 6 u from the screen's
// edge and 4 u above the taskbar, where the tray windows rise. It floats
// beside the work and takes the keyboard only when clicked, so summoning it
// never steals typing; its caption stays inactive (grey) until then.
// Minimize puts it on the taskbar as a button; the Properties sheet opens
// beside it on the left, or over it when the screen has no room.
//
// One layer surface over the work area (the taskbar's zone left out): its
// input mask is the window, the sheet and an open menu, so the rest of the
// screen stays the work's.
PanelWindow {
    id: win

    required property var desktop
    required property var controller
    required property var panel

    readonly property bool wanted: controller.windowShown && !controller.minimized
    readonly property real u: Win98Tokens.unitFor(win)
    screen: desktop.screen
    visible: wanted

    anchors { top: true; bottom: true; left: true; right: true }
    // Normal: the surface stays out of the taskbar's exclusive zone.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "mountainous-fleet"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // The work area in units; before the first map, the screen's.
    readonly property real areaW: width > 0 ? width : (screen ? screen.width : 1920)
    readonly property real areaH: height > 0 ? height : (screen ? screen.height - Math.ceil(28 * u) : 1162)
    readonly property int wU: Math.floor(areaW / u + 1e-6)
    readonly property int hU: Math.floor(areaH / u + 1e-6)
    readonly property int frameU: Math.min(Math.round(view.naturalWidth / u), Math.max(Plan.C.MINW, wU - Plan.GP.LEFT - Plan.GP.RIGHT))
    readonly property var rect: Plan.standaloneRect(wU, hU, frameU, Math.round(view.restHeight / u))
    readonly property var area: ({ x: Plan.GP.LEFT, y: Plan.GP.TOP, w: wU - Plan.GP.LEFT - Plan.GP.RIGHT, h: hU - Plan.GP.TOP - Plan.GP.BOTTOM })
    readonly property bool focused: frame.Window.active

    function close() { win.controller.closeFleet(); }
    // Esc: a menu first, then the sheet, then the window.
    function goBack() {
        if (view.menuOpen !== "") view.menuOpen = "";
        else if (win.panel.expanded !== "") win.panel.expanded = "";
        else win.close();
    }

    mask: Region {
        item: frame
        Region { item: sheet.item ? sheet : null }
        Region { item: view.menuOpen !== "" ? menuLayer : null }
    }

    // The Properties sheet's host view, when its host is still listed.
    readonly property var openHost: {
        const name = win.panel.expanded;
        if (name === "") return null;
        for (const v of win.panel.fleet.hosts) if (v.name === name) return v;
        return null;
    }

    Win98Window {
        id: frame
        x: win.rect.x * win.u
        y: win.rect.y * win.u
        width: win.rect.w * win.u
        height: view.restHeight
        focus: true
        margins: false
        active: win.focused && !(sheet.item && (sheet.item as Item).activeFocus)
        showMinimize: true
        title: view.captionText(win.rect.w - 6 - 16 - 3 - 2 * 21 - 8)
        iconItem: Component {
            Win98HostIcon {
                hostStatus: HostIcon.fleetLook(win.panel.fleet, win.panel.stale).status
                tone: HostIcon.fleetLook(win.panel.fleet, win.panel.stale).tone
            }
        }
        onCloseClicked: win.close()
        onMinimizeClicked: win.controller.minimize()
        onIconClicked: view.openControlMenu(frame)

        Win98FleetView {
            id: view
            objectName: "fleetView"
            width: frame.width - frame.frame * 2
            panel: win.panel
            prefs: win.controller
            menuLayer: menuLayer
            focus: true
            frameWidth: frame.width
            maxFrameHeight: win.area.h * win.u
            active: win.focused
            canMinimize: true
            onEscapePressed: win.goBack()
            onCloseRequested: win.close()
            onMinimizeRequested: win.controller.minimize()
        }
    }

    Timer {
        id: focusRestore
        interval: 0
        onTriggered: view.forceActiveFocus()
    }

    Loader {
        id: sheet
        objectName: "fleetSheet"
        active: win.openHost !== null && win.wanted
        // A closed sheet gives the keyboard back to the list, once it is gone.
        onActiveChanged: if (!active) focusRestore.restart()
        readonly property var place: Plan.sheetRect(win.rect, win.area)
        x: place.x * win.u
        y: place.y * win.u
        width: place.w * win.u
        height: place.h * win.u
        sourceComponent: Win98FleetProperties {
            width: sheet.width
            height: sheet.height
            panel: win.panel
            prefs: win.controller
            hv: win.openHost
            active: win.focused && activeFocus
            onEscapePressed: view.forceActiveFocus()
            Component.onCompleted: forceActiveFocus()
        }
    }

    // Menus and the tooltip draw here, over the window and the sheet.
    Item {
        id: menuLayer
        width: win.areaW
        height: win.areaH
        z: 5
    }

    Shortcut {
        sequences: ["Ctrl+Tab"]
        context: Qt.WindowShortcut
        enabled: sheet.item !== null
        onActivated: win.controller.tab = (win.controller.tab + 1) % 4
    }

    function rectOf(item) {
        if (!item || !item.visible) return null;
        const q = item.mapToItem(null, 0, 0);
        return { x: q.x, y: q.y, w: item.width, h: item.height };
    }
    function debug() {
        const p = view.plan;
        return {
            visible: win.visible, width: win.width, height: win.height, u: win.u, focused: win.focused,
            frame: win.rectOf(frame), sheet: sheet.item ? win.rectOf(sheet) : null, sheetBeside: sheet.place.beside,
            title: frame.title, menu: view.menuOpen, menuRect: view.menuItem ? win.rectOf(view.menuItem) : null,
            level: p.level, cols: p.cols, rowH: p.rowH, menuInCap: p.menuInCap, scrolls: p.scrolls,
            natural: view.naturalWidth, view: win.controller.view, rows: view.rowNames
        };
    }

    // A press outside the window and the sheet closes an open menu.
    HyprlandFocusGrab {
        active: win.visible && view.menuOpen !== ""
        windows: [win]
        onCleared: view.menuOpen = ""
    }
}
