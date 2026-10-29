import Hensou as Kit
import Quickshell
import QtQuick

// One screen's Fleet views for the Platinum Desktop: the standalone Fleet
// window, the glance space, and the Glance menu the bar's Fleet readout
// opens. The data is the shared Beszel owner (context.beszel); where a
// context has none (an older harness, another shell), nothing here exists
// and the bar shows no readout.
Scope {
    id: root

    required property var desktop
    required property var bar

    readonly property var screen: desktop.screen
    readonly property var beszel: desktop.context.beszel !== undefined ? desktop.context.beszel : null
    readonly property var storage: desktop.context.storage !== undefined ? desktop.context.storage : null
    readonly property bool present: beszel !== null

    readonly property bool windowShown: present && desktop.active && GlanceState.fleetScreen === desktop.screen
    readonly property bool glanceShown: present && desktop.active && GlanceState.glanceScreen === desktop.screen
    readonly property bool readoutShown: present && desktop.active && desktop.context.shell.chromeVisible
    // Beszel refreshes while any of these shows; the drill-down only while
    // a window shows.
    readonly property bool shown: readoutShown || windowShown || glanceShown
    readonly property bool detailShown: windowShown || glanceShown
    readonly property Component menu: present ? menuComponent : null

    // Super+B, Super+O F. From the glance space it goes back to the work:
    // the space leaves and the window opens.
    function toggleFleet() {
        if (!present) return;
        if (root.glanceShown) { GlanceState.hideGlance(null); GlanceState.showFleet(root.screen); return; }
        GlanceState.toggleFleet(root.screen);
    }
    function openFleetWindow() {
        if (!present) return;
        if (root.glanceShown) { GlanceState.hideGlance(null); GlanceState.showFleet(root.screen); return; }
        if (root.windowShown) GlanceState.hideFleet();
        else GlanceState.showFleet(root.screen);
    }
    // Super+W, the Glance menu. from: the screen rect the zoom starts at.
    function toggleGlance(from) {
        if (!present) return;
        GlanceState.toggleGlance(root.screen, from || null);
    }
    function showGlance() { if (present && !root.glanceShown) GlanceState.showGlance(root.screen, null); }
    function hideGlance() { if (root.glanceShown) GlanceState.hideGlance(null); }

    // The readout's place on the bar, for the zoom rects: the readout, or
    // » when it overflowed.
    function readoutRect() {
        const r = root.bar.controlRect ? root.bar.controlRect("fleet") : null;
        return r ? {x: r.x, y: 0, w: r.w, h: Kit.PlatinumTokens.barHeight} : null;
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

    Component {
        id: menuComponent
        PlatinumGlanceMenu { desktop: root; beszel: root.beszel }
    }

    Loader {
        active: root.present
        sourceComponent: PlatinumFleetWindow { desktop: root.desktop; panel: root.beszel }
    }

    // Created with the Desktop and only shown and hidden after that.
    Loader {
        active: root.present
        sourceComponent: PlatinumGlanceSpace {
            desktop: root.desktop
            bar: root.bar
            beszel: root.beszel
            storage: root.storage
            controller: root
        }
    }
}
