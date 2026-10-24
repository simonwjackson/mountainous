import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "lanes.js" as Lanes

// One screen's complete chrome. Data owners outlive this theme instance.
Scope {
    id: desktop
    required property var screen
    required property var context
    required property var theme
    property bool active: false
    readonly property string diagnostics: " bar=" + PlatinumTokens.barSurface
        + " rule=" + (PlatinumTokens.barRuled ? PlatinumTokens.barRule : "none")

    function reveal() {
        context.shell.chromeVisible = true;
        context.shell.chromeAccessVisible = true;
    }
    function hide() { context.shell.chromeAccessVisible = false; }
    function open(control) {
        if (control === "theme") { ThemePicker.open(screen); return; }
        if (!menuMap[control]) return;
        if (control === "builder") context.shell.builderKeyboard = true;
        context.shell.openMenu(control, desktop.screen);
    }

    // The installed registry selects this theme's picker. The shared model
    // persists across PlatinumDesktop swaps; the view is destroyed with its theme.
    Loader {
        active: desktop.active && ThemePicker.visible && ThemePicker.screen === desktop.screen
        function loadView() {
            if (active) setSource(Qt.resolvedUrl(desktop.theme.picker),
                {screen: desktop.screen, model: ThemePicker});
        }
        onActiveChanged: loadView()
        Component.onCompleted: loadView()
    }

    Component { id: btMenu; PlatinumBluetoothMenu { panel: desktop.context.bluetooth } }
    Component { id: wifiMenu; PlatinumWifiMenu { panel: desktop.context.wifi } }
    Component { id: volMenu; PlatinumSoundMenu { panel: desktop.context.sound } }
    Component { id: briMenu; PlatinumBrightnessMenu { panel: desktop.context.brightness } }
    Component { id: ociMenu; PlatinumOciEgressMenu { panel: desktop.context.oci } }
    Component { id: diskMenu; PlatinumStorageHealthMenu { panel: desktop.context.storage } }
    Component { id: builderMenu; PlatinumBuilderMenu { panel: desktop.context.builder } }
    Component { id: ntfMenu; PlatinumNotificationCentreMenu { panel: desktop.context.centre } }

    // Fleet: its bar readout, the Fleet window and the glance space.
    PlatinumFleetGlance { id: fleetGlance; desktop: desktop; bar: topBar }
    readonly property bool fleetShown: fleetGlance.shown
    readonly property bool fleetDetailShown: fleetGlance.detailShown
    function toggleFleet() { fleetGlance.toggleFleet(); }
    function toggleGlance() { fleetGlance.toggleGlance(null); }
    function showGlance() { fleetGlance.showGlance(); }
    function hideGlance() { fleetGlance.hideGlance(); }

    PlatinumTopBar {
        id: topBar
        modelData: desktop.screen
        beszel: fleetGlance.beszel
        visible: desktop.active && desktop.context.shell.chromeVisible
        bluetooth: desktop.context.bluetooth
        wifi: desktop.context.wifi
        sound: desktop.context.sound
        brightness: desktop.context.brightness
        oci: desktop.context.oci
        storage: desktop.context.storage
        notifications: desktop.context.notifications
        dictation: desktop.context.dictation
        omniBar: desktop.context.omniBar
        frontWindow: desktop.context.frontWindow
        builderGate: desktop.context.builderGate
        now: desktop.context.now
        chordVisible: desktop.context.shell.chromeAccessVisible
    }

    // The shadow under this bar. It shows and hides with the bar.
    PlatinumBarShadow { bar: topBar }

    Component {
        id: clockMenu
        PlatinumClockMenu { now: desktop.context.now }
    }

    Component {
        id: overflowMenu
        PlatinumOverflowMenu { bar: topBar }
    }

    readonly property var menuMap: ({
            bt: btMenu,
            wifi: wifiMenu,
            vol: volMenu,
            bri: briMenu,
            oci: desktop.context.oci.enabled ? ociMenu : null,
            disk: desktop.context.storage.enabled ? diskMenu : null,
            fleet: fleetGlance.menu,
            ntf: ntfMenu,
            builder: desktop.context.builderGate.enabled ? builderMenu : null,
            clock: clockMenu,
            more: overflowMenu
        })

    PlatinumMenuHost {
        enabled: desktop.active
        screen: desktop.screen
        bar: topBar
        menus: desktop.menuMap
    }

    PanelWindow {
        id: dockWindow

        readonly property var modelData: desktop.screen
        screen: modelData
        visible: desktop.active && desktop.context.shell.chromeVisible

        // This screen's windows only. See desktop.context.shell.windowsOn.
        readonly property var lane: desktop.context.shell.windowsOn(modelData)

        anchors { bottom: true; left: true; right: true }
        implicitHeight: 44
        // Kamoi: "a floating window dock reserves space at the
        // bottom". The margin floats it; the anchors reserve it.
        margins { bottom: 6; left: 6; right: 6 }
        color: "transparent"

        Rectangle {
            id: dock
            anchors.centerIn: parent
            implicitWidth: dockRow.implicitWidth + 16
            implicitHeight: 38
            radius: PlatinumTokens.radiusMedium
            color: PlatinumTokens.bgPanel
            visible: dockWindow.lane.length > 0

            // -1 means no drag is in progress. Holding both ends
            // here rather than in each icon keeps one owner for the
            // gesture, so the icons only read it.
            property int dragIndex: -1
            property int dropIndex: -1

            // The row is one flat strip, so the icon under the
            // pointer is whatever child sits at that x. childAt
            // returns the slot, and each slot knows its own index.
            function slotIndexAt(x, y) {
                const item = dockRow.childAt(x, y);
                return (item && item.slotIndex !== undefined) ? item.slotIndex : -1;
            }

            RowLayout {
                id: dockRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: ScriptModel { values: dockWindow.lane }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        // dock.slotIndexAt reads this off whatever
                        // childAt returns, so a drop can name the
                        // window it landed on.
                        readonly property int slotIndex: index

                        // A hairline before the first window of each
                        // workspace, so the strip's shape is visible
                        // without labelling every group.
                        readonly property bool startsWorkspace: {
                            if (index === 0) return false;
                            const here = desktop.context.shell.pageOf(modelData);
                            const prev = desktop.context.shell.pageOf(dockWindow.lane[index - 1]);
                            // While either window is between pages,
                            // draw nothing rather than a separator
                            // that moves again a moment later.
                            if (here < 0 || prev < 0) return false;
                            return here !== prev;
                        }

                        implicitWidth: 30 + (startsWorkspace ? 9 : 0)
                        implicitHeight: 30
                        radius: PlatinumTokens.radiusSmall
                        color: "transparent"

                        Rectangle {
                            visible: parent.startsWorkspace
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: 18
                            color: PlatinumTokens.bgSeparator
                        }

                        Rectangle {
                            id: cell
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            radius: PlatinumTokens.radiusSmall
                            // The focused window is marked, on
                            // whichever screen has focus. Windows on
                            // pages this screen is not showing are
                            // dimmed rather than hidden, so the
                            // screen's whole session reads at a
                            // glance. "Showing" is per screen: focus
                            // on the other screen does not dim this
                            // one. A window between pages is not
                            // shown anywhere, so it stays dimmed.
                            color: modelData.activated ? PlatinumTokens.bgActive : "transparent"
                            opacity: Lanes.isShown(modelData) ? 1.0 : 0.45

                            // A toplevel has no wayland handle until
                            // Hyprland reports its address, so appId
                            // is briefly empty. iconPath("") builds a
                            // malformed url and the journal fills up
                            // with: Could not load icon "?fallback="
                            readonly property string appId: {
                                const wl = modelData.wayland;
                                return wl && wl.appId ? wl.appId : "";
                            }

                            // A window class is not an icon name.
                            // Chromium reports the class
                            // chromium-browser while its icon is
                            // named chromium, so asking the theme
                            // for the class filled the journal
                            // with: Could not load icon
                            // "chromium-browser?fallback=...".
                            //
                            // The desktop entry is the mapping
                            // between the two. heuristicLookup
                            // matches on id, name and
                            // StartupWMClass, which is how the
                            // --app web apps resolve: their class
                            // is chrome-<host>__-Default and only
                            // their entry knows that.
                            readonly property string iconName: {
                                if (cell.appId === "") return "";
                                const e = DesktopEntries.heuristicLookup(cell.appId);
                                return (e && e.icon) ? e.icon : cell.appId;
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 20
                                visible: source !== ""
                                source: cell.iconName === ""
                                    ? ""
                                    : Quickshell.iconPath(cell.iconName, "application-x-executable")
                            }

                            // Until the icon resolves, show the first
                            // letter rather than an empty square.
                            Text {
                                anchors.centerIn: parent
                                visible: cell.appId === ""
                                text: (modelData.title || "?").charAt(0).toUpperCase()
                                color: PlatinumTokens.textSecondary
                                font.pixelSize: 13
                                font.family: PlatinumTokens.fontFamily
                            }

                            // The icon lifts while it is dragged, and
                            // the icon under the pointer lights up, so
                            // the drop target is never a guess.
                            scale: dock.dragIndex === index ? 1.18 : 1.0
                            border.width: dock.dropIndex === index
                                          && dock.dragIndex !== index ? 1 : 0
                            border.color: PlatinumTokens.accent

                            MouseArea {
                                id: grip
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                // A click and a drag start the same
                                // way, so the gesture only becomes a
                                // drag after the pointer travels far
                                // enough to rule out a shaky click.
                                readonly property int threshold: 8
                                property real pressX: 0
                                property bool dragging: false

                                function targetAt(mx, my) {
                                    const p = grip.mapToItem(dockRow, mx, my);
                                    return dock.slotIndexAt(p.x, p.y);
                                }

                                onPressed: function (mouse) {
                                    grip.pressX = mouse.x;
                                    grip.dragging = false;
                                }

                                onPositionChanged: function (mouse) {
                                    if (!(mouse.buttons & Qt.LeftButton)) return;
                                    if (!grip.dragging
                                        && Math.abs(mouse.x - grip.pressX) < grip.threshold) return;
                                    grip.dragging = true;
                                    dock.dragIndex = index;
                                    dock.dropIndex = grip.targetAt(mouse.x, mouse.y);
                                }

                                onReleased: function (mouse) {
                                    if (!grip.dragging) return;
                                    desktop.context.shell.dropOnto(dockWindow.lane, index, grip.targetAt(mouse.x, mouse.y));
                                    dock.dragIndex = -1;
                                    dock.dropIndex = -1;
                                }

                                // A release after a drag still emits
                                // clicked, and activating the window
                                // there would undo the drop by pulling
                                // focus to the old page.
                                onClicked: function (mouse) {
                                    if (grip.dragging) { grip.dragging = false; return; }
                                    const wl = modelData.wayland;
                                    if (!wl) return;
                                    // Go through the Wayland toplevel
                                    // protocol, not Hyprland.dispatch:
                                    // dispatcher syntax differs under
                                    // a Lua config (Hyprland.usingLua)
                                    // and this path avoids the issue.
                                    // activate() also pulls the focus
                                    // to that window's workspace.
                                    if (mouse.button === Qt.MiddleButton) wl.close();
                                    else wl.activate();
                                }

                                onCanceled: {
                                    grip.dragging = false;
                                    dock.dragIndex = -1;
                                    dock.dropIndex = -1;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
