// Kamoi's two bars. See modules/bars.nix for provenance.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "lanes.js" as Lanes

ShellRoot {
    id: root

    // Kamoi Meta+I hides the top bar and the dock together.
    property bool chromeVisible: true
    property bool topbarAccessVisible: false
    property var bluetoothScreen: null
    property var wifiScreen: null
    property var soundScreen: null
    property var brightnessScreen: null
    property var ociScreen: null
    property var storageScreen: null

    function toggleBluetooth(screen) {
        root.topbarAccessVisible = false;
        root.storageScreen = null;
        root.wifiScreen = null;
        root.soundScreen = null;
        root.brightnessScreen = null;
        root.bluetoothScreen = root.bluetoothScreen === screen ? null : screen;
    }

    function toggleWifi(screen) {
        root.topbarAccessVisible = false;
        root.storageScreen = null;
        root.bluetoothScreen = null;
        root.soundScreen = null;
        root.brightnessScreen = null;
        root.wifiScreen = root.wifiScreen === screen ? null : screen;
    }

    function toggleSound(screen) {
        root.topbarAccessVisible = false;
        root.storageScreen = null;
        root.bluetoothScreen = null;
        root.wifiScreen = null;
        root.brightnessScreen = null;
        root.soundScreen = root.soundScreen === screen ? null : screen;
    }

    function toggleBrightness(screen) {
        root.topbarAccessVisible = false;
        root.bluetoothScreen = null;
        root.wifiScreen = null;
        root.soundScreen = null;
        root.ociScreen = null;
        root.storageScreen = null;
        root.brightnessScreen = root.brightnessScreen === screen ? null : screen;
    }

    function toggleOci(screen) {
        root.topbarAccessVisible = false;
        root.bluetoothScreen = null;
        root.wifiScreen = null;
        root.soundScreen = null;
        root.brightnessScreen = null;
        root.storageScreen = null;
        root.ociScreen = root.ociScreen === screen ? null : screen;
    }

    function toggleStorage(screen) {
        root.topbarAccessVisible = false;
        root.bluetoothScreen = null;
        root.wifiScreen = null;
        root.soundScreen = null;
        root.brightnessScreen = null;
        root.ociScreen = null;
        root.storageScreen = root.storageScreen === screen ? null : screen;
    }

    // The keyboard hint lists only the panels this host shows.
    function topbarAccessHint(cloud, disks) {
        let keys = ["B Bluetooth", "W Wi-Fi", "S Sound", "L Brightness"];
        if (cloud) keys.push("C Cloud");
        if (disks) keys.push("D Disks");
        keys.push("Esc cancel");
        return keys.join("  ·  ");
    }

    function primaryScreen() {
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    // The omni bar. Its component lives in modules/omni.nix, which
    // QML resolves by filename from this directory.
    OmniBar { id: omniBar }

    // One owner for capture, queueing, backend work, insertion, and the
    // bottom-centre state overlay. The top bar only reads its public state.
    Dictation { id: dictation }

    // Quickshell 0.3.1 registers IPC handlers reliably at the shell root. Keep
    // transport here and forward every event to the dictation state owner.
    IpcHandler {
        target: "dictation"
        function press(): void { dictation.press(false); }
        function pressEnter(): void { dictation.press(true); }
        function release(): void { dictation.release(); }
        function cancel(): void { dictation.cancel(); }
        function retry(): void { dictation.retryFailed(); }
        function dismiss(): void { dictation.dismissFailure(); }
        function current(): string {
            return dictation.state + " "
                + (dictation.backend || "none") + " "
                + dictation.queueCount;
        }
    }

    // Reached from the compositor with:  qs -c mountainous ipc call chrome toggle
    IpcHandler {
        target: "chrome"
        function toggle(): void { root.chromeVisible = !root.chromeVisible; }
        function hide(): void   { root.chromeVisible = false; }
        // Named reveal, not show: `qs ipc call chrome show` returns the
        // interface listing and does nothing, because `show` collides
        // with the qs CLI's own introspection verb. toggle and hide
        // both work, and Meta+I uses toggle.
        function reveal(): void { root.chromeVisible = true; }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): void { root.toggleBluetooth(root.primaryScreen()); }
        function hide(): void { root.bluetoothScreen = null; }
        function reveal(): void {
            root.topbarAccessVisible = false;
            root.bluetoothScreen = root.primaryScreen();
        }
    }

    IpcHandler {
        target: "wifi"
        function toggle(): void { root.toggleWifi(root.primaryScreen()); }
        function hide(): void { root.wifiScreen = null; }
        function reveal(): void {
            root.topbarAccessVisible = false;
            root.bluetoothScreen = null;
            root.wifiScreen = root.primaryScreen();
        }
    }

    IpcHandler {
        target: "sound"
        function toggle(): void { root.toggleSound(root.primaryScreen()); }
        function hide(): void { root.soundScreen = null; }
        function reveal(): void {
            root.topbarAccessVisible = false;
            root.bluetoothScreen = null;
            root.wifiScreen = null;
            root.soundScreen = root.primaryScreen();
        }
    }

    IpcHandler {
        target: "brightness"
        function toggle(): void { root.toggleBrightness(root.primaryScreen()); }
        function hide(): void { root.brightnessScreen = null; }
        function reveal(): void {
            root.brightnessScreen = null;
            root.toggleBrightness(root.primaryScreen());
        }
    }

    IpcHandler {
        target: "oci"
        function reveal(): void { root.toggleOci(root.primaryScreen()); }
        function hide(): void { root.ociScreen = null; }
    }

    IpcHandler {
        target: "storage"
        function reveal(): void { root.toggleStorage(root.primaryScreen()); }
        function hide(): void { root.storageScreen = null; }
    }

    IpcHandler {
        target: "topbar"
        function hide(): void { root.topbarAccessVisible = false; }
        function reveal(): void {
            root.chromeVisible = true;
            root.topbarAccessVisible = true;
        }
    }

    // Quickshell 0.3.1 drops an openwindow event when Hyprland creates the
    // destination workspace at the same time. Its journal says:
    //
    //   Got openwindow for workspace "1" which was not previously tracked.
    //
    // The missing event leaves Hyprland.toplevels one window behind until a
    // later full refresh. Refresh workspaces first, then toplevels. The timer
    // is a fallback when the workspace already existed and valuesChanged does
    // not fire. movewindowv2 has the same race for a newly created page.
    Timer {
        id: dockToplevelRefresh
        interval: 100
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland.workspaces

        function onValuesChanged() {
            if (!dockToplevelRefresh.running) return;
            dockToplevelRefresh.stop();
            Hyprland.refreshToplevels();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "openwindow" && event.name !== "movewindowv2") return;
            dockToplevelRefresh.restart();
            Hyprland.refreshWorkspaces();
        }
    }

    // One screen's windows, ordered along its pages. Each screen is its
    // own lane: its dock lists every page on that screen, and none of
    // the other screen's. See lanes.js.
    //
    // Every page, not just the one showing: the dock is how you see the
    // screen's whole session at once, so a window two pages away is
    // reachable in one click rather than by walking the strip to find it.
    function windowsOn(screen) {
        return Lanes.windowsOn(Hyprland.toplevels.values, screen ? screen.name : "");
    }

    // Which page a window is on, or -1 while it is between pages.
    //
    // windowsOn filters on t.workspace before building the list, but
    // that only makes the list safe at the moment it is built. Each
    // delegate binding re-runs when the property changes, and Hyprland
    // nulls workspace while it moves or closes a window, so the filter
    // cannot protect the delegate. Reproduced on hiyori by moving one
    // window across pages and closing it:
    //
    //   WARN scene: @shell.qml[242]: TypeError: Cannot read property
    //                                'id' of null
    //   WARN scene: @shell.qml[272]: same
    //
    // -1 is safe as the unknown value because windowsOn keeps only
    // ids above zero; special workspaces are already excluded.
    function pageOf(toplevel) {
        return Lanes.pageOf(toplevel);
    }

    // Hyprland addresses a window as address:0x... in a dispatcher.
    // The Wayland handle carries no address, so it comes from the last
    // IPC payload, which is empty until Hyprland has reported the
    // window once.
    function addressOf(toplevel) {
        const o = toplevel ? toplevel.lastIpcObject : null;
        return (o && o.address) ? o.address : "";
    }

    // Kamoi's dock shows one page, so dragging an icon onto another
    // swaps two window positions. This dock shows every page, which
    // makes a drop across a page boundary mean something else: send
    // the window to that page. Inside one page it still swaps.
    //
    // Both actions go through hyprctl rather than the Wayland toplevel
    // protocol, because neither has a protocol equivalent. The two
    // dispatchers differ in shape, measured on hiyori:
    //
    //   window.move accepts `window`, so it names its own subject.
    //   window.swap does not. It acts on the focused window, so the
    //   dragged window has to be focused first, in the same batch to
    //   keep the two steps from racing.
    //
    // Both indices are into one dock's list, so a drag never leaves its
    // screen. Each dock is a separate surface, and a pointer drag cannot
    // cross from one surface to another.
    function dropOnto(windows, fromIndex, toIndex) {
        if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return;

        const from = windows[fromIndex];
        const to   = windows[toIndex];
        const a = root.addressOf(from);
        const b = root.addressOf(to);
        if (a === "" || b === "") return;

        const fromPage = root.pageOf(from);
        const toPage   = root.pageOf(to);
        if (fromPage < 0 || toPage < 0) return;

        if (fromPage === toPage) {
            Quickshell.execDetached(["hyprctl", "--batch",
                'dispatch hl.dsp.focus({ window = "address:' + a + '" }) ; '
                + 'dispatch hl.dsp.window.swap({ target = "address:' + b + '" })']);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch",
                'hl.dsp.window.move({ window = "address:' + a + '", '
                + 'workspace = ' + toPage + ' })']);
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function formatClock(date) {
        const hour = date.getHours() % 12 || 12;
        return Qt.formatDateTime(date, "M/d  ")
            + hour
            + Qt.formatDateTime(date, ":mm");
    }

    //----------------------------------------------------------------
    // TOP BAR
    //----------------------------------------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: topBar

            required property var modelData
            screen: modelData
            visible: root.chromeVisible

            // The window that last had focus on this screen. The title
            // below falls back to it once focus moves to another screen,
            // so this bar keeps naming what this screen shows.
            property var lastFocused: null

            Connections {
                target: Hyprland

                function onActiveToplevelChanged() {
                    const t = Hyprland.activeToplevel;
                    if (t && Lanes.screenOf(t) === topBar.modelData.name) topBar.lastFocused = t;
                }
            }

            readonly property var frontWindow: Lanes.frontWindow(
                Hyprland.toplevels.values, modelData.name,
                Hyprland.activeToplevel, lastFocused)

            BluetoothPanel {
                id: bluetoothPanel
                screen: modelData
                shown: root.bluetoothScreen === modelData
                onCloseRequested: root.bluetoothScreen = null
            }

            WifiPanel {
                id: wifiPanel
                screen: modelData
                shown: root.wifiScreen === modelData
                onCloseRequested: root.wifiScreen = null
            }

            SoundPanel {
                id: soundPanel
                screen: modelData
                shown: root.soundScreen === modelData
                onCloseRequested: root.soundScreen = null
            }

            BrightnessPanel {
                id: brightnessPanel
                screen: modelData
                shown: root.brightnessScreen === modelData
                onCloseRequested: root.brightnessScreen = null
            }

            OciEgress {
                id: ociEgress
                screen: modelData
                shown: root.ociScreen === modelData
                onCloseRequested: root.ociScreen = null
            }

            StorageHealth {
                id: storageHealth
                screen: modelData
                shown: root.storageScreen === modelData
                onCloseRequested: root.storageScreen = null
            }

            anchors { top: true; left: true; right: true }
            implicitHeight: 26
            color: Theme.bgBase

            // Left: dictation state replaces the window-title readout while
            // it matters. The readout yields before controls, so Retry and
            // Dismiss stay reachable after a failure.
            Item {
                id: leftStatus
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width / 2 - 90)
                height: parent.height

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !dictation.barVisible
                    elide: Text.ElideRight
                    text: topBar.frontWindow ? topBar.frontWindow.title : ""
                    color: Theme.textPage
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                }

                RowLayout {
                    anchors.fill: parent
                    visible: dictation.barVisible
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        radius: 4
                        color: dictation.accentColor
                    }

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: {
                            let value = dictation.statusText;
                            if (dictation.backendLabel !== "") {
                                value += " · " + dictation.backendLabel;
                            }
                            if (dictation.queueCount > 1) {
                                value += " · " + dictation.queueCount;
                            }
                            return value;
                        }
                        color: Theme.textPrimary
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 22
                        visible: dictation.state === "failed" && dictation.canRetry
                        radius: Theme.radiusSmall
                        color: retryArea.containsMouse ? Theme.bgActive : Theme.bgSelected

                        Text {
                            anchors.centerIn: parent
                            text: "Retry"
                            color: Theme.accent
                            font.pixelSize: 9
                            font.family: Theme.fontFamily
                        }

                        MouseArea {
                            id: retryArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: dictation.retryFailed()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 22
                        visible: dictation.state === "failed"
                        radius: Theme.radiusSmall
                        color: dismissArea.containsMouse ? Theme.bgActive : Theme.bgSelected

                        Text {
                            anchors.centerIn: parent
                            text: "Dismiss"
                            color: Theme.textSecondary
                            font.pixelSize: 9
                            font.family: Theme.fontFamily
                        }

                        MouseArea {
                            id: dismissArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: dictation.dismissFailure()
                        }
                    }
                }
            }

            // Centre: the time, or the active keyboard chord.
            Text {
                anchors.centerIn: parent
                text: root.topbarAccessVisible
                    ? root.topbarAccessHint(ociEgress.enabled, storageHealth.enabled)
                    : root.formatClock(clock.date)
                color: root.topbarAccessVisible ? Theme.accent : Theme.textPrimary
                font.pixelSize: 11
                font.family: Theme.fontFamily
            }

            // Right: Bluetooth and Wi-Fi are controls. The power source is a
            // readout, so it yields first when the bar is narrow. Battery
            // percentage stays visible.
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 26
                    visible: bluetoothPanel.adapter !== null
                    color: bluetoothArea.containsMouse ? Theme.bgSelected : "transparent"
                    radius: Theme.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        text: bluetoothPanel.connectedCount > 0
                            ? "BT " + bluetoothPanel.connectedCount
                            : "BT"
                        color: {
                            if (bluetoothPanel.connectedCount > 0) return Theme.accent;
                            return bluetoothPanel.adapter && bluetoothPanel.adapter.enabled
                                ? Theme.textPrimary : Theme.textOff;
                        }
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }

                    MouseArea {
                        id: bluetoothArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.toggleBluetooth(modelData)
                    }
                }

                // Wi-Fi strength. The one status item Kamoi's README
                // actually specifies, at line 32:
                //
                //   "The top bar shows Wi-Fi and cellular signal
                //    strength as fixed-width Lucide icons. It does not
                //    show a network name, carrier name, or cell
                //    identity."
                //
                // Strength only, never the SSID, and a fixed 11px so
                // the bar never reflows as the signal moves. No
                // cellular rung: the Galaxy Book3 has no cellular
                // radio, and Kamoi draws no icon for an absent radio.
                //
                // Written against Quickshell 0.3.1's own
                // quickshell-network.qmltypes:
                //   Networking    singleton, devices UntypedObjectModel
                //   NetworkDevice type DeviceType::Enum, connected,
                //                 networks
                //   WifiDevice  : NetworkDevice
                //   WifiNetwork : Network, signalStrength double
                //
                // signalStrength is 0.0 to 1.0, not 0 to 100. Measured
                // on hiyori against nmcli on the same association:
                // nmcli said 81, this said 0.8.
                //
                // The NetworkManager backend fills in over D-Bus after
                // the engine loads. Sampled on hiyori: at 1.5s
                // devices=0 and wifiEnabled=false, at 3.0s the device
                // is present. Every property read here is notifiable,
                // so the bindings simply fill in and nothing polls.
                Rectangle {
                    id: wifiControl

                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 26
                    visible: Networking.wifiHardwareEnabled && topBar.width >= 420
                    color: wifiArea.containsMouse ? Theme.bgSelected : "transparent"
                    radius: Theme.radiusSmall

                    // Four rungs, so one bar is a quarter of the scale.
                    // Zero bars means the radio is on with no link,
                    // which is a different fact from having no radio.
                    readonly property int level: {
                        if (!wifiPanel.connectedNetwork) return 0;
                        const strength = wifiPanel.connectedNetwork.signalStrength;
                        if (strength >= 0.75) return 4;
                        if (strength >= 0.5) return 3;
                        if (strength >= 0.25) return 2;
                        return 1;
                    }

                    Row {
                        id: wifiBars
                        anchors.centerIn: parent
                        spacing: 1
                        height: 9

                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: 2
                                height: 3 + index * 2
                                y: wifiBars.height - height
                                color: index < wifiControl.level
                                    ? Theme.accent : Theme.textOff
                            }
                        }
                    }

                    MouseArea {
                        id: wifiArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.toggleWifi(modelData)
                    }
                }

                // Volume. The control is always here once PipeWire has a
                // sink, because opening the panel is a capability. The
                // number beside it is a readout, so it is what yields when
                // the bar runs short of width.
                Rectangle {
                    id: soundControl

                    readonly property bool showLevel: topBar.width >= 460

                    Layout.preferredWidth: showLevel ? 50 : 28
                    Layout.preferredHeight: 26
                    visible: soundPanel.available
                    color: soundArea.containsMouse ? Theme.bgSelected : "transparent"
                    radius: Theme.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!soundControl.showLevel) return "VOL";
                            if (soundPanel.muted) return "VOL --";
                            return "VOL " + soundPanel.volumePercent;
                        }
                        color: soundPanel.muted ? Theme.textOff : Theme.textPrimary
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }

                    MouseArea {
                        id: soundArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.toggleSound(modelData)
                    }
                }

                // Brightness: one level for every screen. Same shape as
                // volume: the control stays, the number yields first. The
                // wheel steps it like the keys do.
                Rectangle {
                    id: brightnessControl

                    readonly property bool showLevel: topBar.width >= 520

                    Layout.preferredWidth: showLevel ? 50 : 28
                    Layout.preferredHeight: 26
                    visible: brightnessPanel.available
                    color: brightnessArea.containsMouse ? Theme.bgSelected : "transparent"
                    radius: Theme.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        text: brightnessControl.showLevel
                            ? "BRI " + brightnessPanel.shownLevel
                            : "BRI"
                        color: Theme.textPrimary
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }

                    MouseArea {
                        id: brightnessArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.toggleBrightness(modelData)
                        onWheel: function (wheel) {
                            if (wheel.angleDelta.y !== 0)
                                brightnessPanel.step(wheel.angleDelta.y > 0 ? 1 : -1);
                        }
                    }
                }

                Rectangle {
                    id: ociControl
                    visible: ociEgress.enabled
                    Layout.preferredWidth: topBar.width >= 900 ? 130 : 48
                    Layout.preferredHeight: 26
                    radius: Theme.radiusSmall
                    color: ociArea.containsMouse ? Theme.bgSelected : "transparent"
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: topBar.width >= 900 ? ociEgress.label : "OCI"
                        color: ociEgress.statusColor
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }
                    MouseArea {
                        id: ociArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.toggleOci(modelData)
                    }
                }

                // A readout that opens a panel. Narrow bars keep the count
                // and colour; the panel holds every finding.
                Rectangle {
                    id: storageControl
                    visible: storageHealth.enabled
                    Layout.preferredWidth: topBar.width >= 900 ? 104 : 52
                    Layout.preferredHeight: 26
                    radius: Theme.radiusSmall
                    color: storageArea.containsMouse ? Theme.bgSelected : "transparent"
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: topBar.width >= 900 ? storageHealth.label : storageHealth.shortLabel
                        color: storageHealth.statusColor
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }
                    MouseArea {
                        id: storageArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.toggleStorage(modelData)
                    }
                }

                Text {
                    visible: topBar.width >= 360
                    text: UPower.onBattery ? "BAT" : "AC"
                    color: Theme.textMuted
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                }

                Text {
                    readonly property var dev: UPower.displayDevice
                    text: dev ? Math.round(dev.percentage * 100) + "%" : ""
                    visible: text !== ""
                    color: Theme.textPrimary
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                }
            }
        }
    }

    //----------------------------------------------------------------
    // BOTTOM DOCK
    //----------------------------------------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWindow

            required property var modelData
            screen: modelData
            visible: root.chromeVisible

            // This screen's windows only. See root.windowsOn.
            readonly property var lane: root.windowsOn(modelData)

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
                radius: Theme.radiusMedium
                color: Theme.bgPanel
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
                                const here = root.pageOf(modelData);
                                const prev = root.pageOf(dockWindow.lane[index - 1]);
                                // While either window is between pages,
                                // draw nothing rather than a separator
                                // that moves again a moment later.
                                if (here < 0 || prev < 0) return false;
                                return here !== prev;
                            }

                            implicitWidth: 30 + (startsWorkspace ? 9 : 0)
                            implicitHeight: 30
                            radius: Theme.radiusSmall
                            color: "transparent"

                            Rectangle {
                                visible: parent.startsWorkspace
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: 18
                                color: Theme.bgSeparator
                            }

                            Rectangle {
                                id: cell
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 30
                                radius: Theme.radiusSmall
                                // The focused window is marked, on
                                // whichever screen has focus. Windows on
                                // pages this screen is not showing are
                                // dimmed rather than hidden, so the
                                // screen's whole session reads at a
                                // glance. "Showing" is per screen: focus
                                // on the other screen does not dim this
                                // one. A window between pages is not
                                // shown anywhere, so it stays dimmed.
                                color: modelData.activated ? Theme.bgActive : "transparent"
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
                                    color: Theme.textSecondary
                                    font.pixelSize: 13
                                    font.family: Theme.fontFamily
                                }

                                // The icon lifts while it is dragged, and
                                // the icon under the pointer lights up, so
                                // the drop target is never a guess.
                                scale: dock.dragIndex === index ? 1.18 : 1.0
                                border.width: dock.dropIndex === index
                                              && dock.dragIndex !== index ? 1 : 0
                                border.color: Theme.accent

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
                                        root.dropOnto(dockWindow.lane, index, grip.targetAt(mouse.x, mouse.y));
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
}
