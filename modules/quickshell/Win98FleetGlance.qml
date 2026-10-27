pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "beszel-model.js" as FleetModel

// One screen's Fleet views for the Windows 98 Desktop: the Fleet window
// above the tray, its Properties sheet, a minimized Fleet's taskbar button,
// and the glance space. The data is the shared Beszel owner
// (context.beszel) and the Disks accessory's StorageHealth owner; where a
// context has no Beszel (an older harness, another shell), nothing here
// exists and the tray shows no Fleet icon. Which screen shows the window
// and the space is the shared GlanceState, as under Platinum.
//
// The Win98 view state lives here, shared by both hosts on this screen:
// Details or Large Icons, the Properties sheet's tab, and whether the
// window is minimized to the taskbar.
Scope {
    id: root

    required property var desktop
    required property var taskbar

    readonly property var screen: desktop.screen
    readonly property var beszel: desktop.context.beszel !== undefined ? desktop.context.beszel : null
    readonly property var storage: desktop.context.storage !== undefined ? desktop.context.storage : null
    readonly property bool present: beszel !== null

    readonly property bool windowShown: present && desktop.active && GlanceState.fleetScreen === desktop.screen
    readonly property bool glanceShown: present && desktop.active && GlanceState.glanceScreen === desktop.screen
    // The tray's Fleet icon is a Fleet view: its tone needs a current sample.
    readonly property bool trayShown: present && desktop.active && desktop.shell.chromeVisible
    // Beszel refreshes while any of these shows; the drill-down only while
    // a window or the space shows (a minimized window still polls, as a
    // shaded Platinum window does).
    readonly property bool shown: trayShown || windowShown || glanceShown
    readonly property bool detailShown: windowShown || glanceShown

    property string view: "details"     // or "icons"
    property int tab: 0                 // General, Performance, Services, Disks
    property bool minimized: false
    onWindowShownChanged: if (!windowShown) minimized = false

    // Super+B, Super+O F, the tray icon. From the glance space it goes back
    // to the work: the space leaves and the window opens. A minimized
    // window comes back.
    function toggleFleet() {
        if (!present) return;
        if (root.glanceShown) { GlanceState.hideGlance(null); root.minimized = false; GlanceState.showFleet(root.screen); return; }
        if (root.windowShown && root.minimized) { root.minimized = false; return; }
        if (root.windowShown) root.closeFleet();
        else GlanceState.showFleet(root.screen);
    }
    function closeFleet() {
        if (root.beszel) root.beszel.expanded = "";
        root.minimized = false;
        GlanceState.hideFleet();
    }
    function minimize() { if (root.windowShown) root.minimized = true; }
    function restore() { root.minimized = false; }
    // Super+W, the Glance menu, the Glance button's double-click.
    function toggleGlance() {
        if (!present) return;
        GlanceState.toggleGlance(root.screen, null);
    }
    function showGlance() { if (present && !root.glanceShown) GlanceState.showGlance(root.screen, null); }
    function hideGlance() { if (root.glanceShown) GlanceState.hideGlance(null); }

    // The minimized window's button: "Fleet: 1 problem: unzen".
    readonly property string buttonText: {
        if (!present) return "Fleet";
        const v = FleetModel.summaryVariants(beszel.fleet, true, "");
        return "Fleet: " + (v[2] || v[1]);
    }

    property bool wasActive: false
    Connections {
        target: root.desktop
        function onActiveChanged() {
            if (root.wasActive && !root.desktop.active) GlanceState.forget(root.screen);
            root.wasActive = root.desktop.active;
        }
    }
    Component.onCompleted: wasActive = desktop.active
    Component.onDestruction: GlanceState.forget(root.screen)

    // For the harness and checks: where everything stands, in logical px.
    readonly property var fleetWindow: windowLoader.item
    readonly property var glanceSpace: spaceLoader.item
    function debug() {
        return {
            present: root.present, windowShown: root.windowShown, glanceShown: root.glanceShown, minimized: root.minimized,
            view: root.view, tab: root.tab, shown: root.shown, detailShown: root.detailShown,
            window: root.fleetWindow ? root.fleetWindow.debug() : null,
            glance: root.glanceSpace ? root.glanceSpace.debug() : null
        };
    }

    Loader {
        id: windowLoader
        active: root.present
        sourceComponent: Win98FleetWindow { controller: root; desktop: root.desktop; panel: root.beszel }
    }

    // Created with the Desktop and only shown and hidden after that.
    Loader {
        id: spaceLoader
        active: root.present
        sourceComponent: Win98GlanceSpace {
            controller: root
            desktop: root.desktop
            taskbar: root.taskbar
            beszel: root.beszel
            storage: root.storage
        }
    }
}
