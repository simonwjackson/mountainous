import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick
import "bar-plan.js" as BarPlan
import "battery.js" as BatteryRule
import "oci-model.js" as OciModel
import "notification-model.js" as NotificationModel

// One screen's top bar, as a Mac OS 8 Platinum menu bar.
//
//   left    the omni mark, then the front window's title or dictation
//   centre  the clock, or the Super+O chord while it is active
//   right   the controls, the battery, the front app
//
// Layout is BarPlan.plan(width, metrics): readouts yield before controls,
// in one declared order, and controls move into the » menu only after
// every readout has yielded. A control hides only when its hardware is
// missing. Each yielded readout still lives in its menu's header.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    // The data owners. The bar only reads them.
    required property var bluetooth
    required property var wifi
    required property var sound
    required property var brightness
    required property var oci
    required property var storage
    required property var notifications
    required property var dictation
    required property var omniBar
    property var frontWindow: null
    property date now: new Date()
    property bool chordVisible: false

    // The battery as UPower reports it. A harness may replace it.
    property var battery: {
        const dev = UPower.displayDevice;
        return {
            present: dev !== null && dev.isPresent,
            percent: dev ? Math.round(dev.percentage * 100) : 0,
            charging: dev ? dev.state === UPowerDeviceState.Charging
                || dev.state === UPowerDeviceState.PendingCharge : false,
            full: dev ? dev.state === UPowerDeviceState.FullyCharged : false,
            onBattery: UPower.onBattery
        };
    }

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: "transparent"

    onDevicePixelRatioChanged: if (devicePixelRatio > 0) Theme.pixelRatio = devicePixelRatio
    Component.onCompleted: if (devicePixelRatio > 0) Theme.pixelRatio = devicePixelRatio

    readonly property bool menuHere: MenuState.current !== "" && MenuState.screen === bar.modelData
    function isOpen(name) { return bar.menuHere && MenuState.current === name; }

    // Where a menu hangs: under its control, under » when the control
    // overflowed, or -1 (top right) when the bar does not show it.
    // It reads x through the parents, not mapToItem, so a binding that
    // calls it follows the bar when its layout changes under an open menu.
    function anchorFor(name) {
        const item = ({
            bt: btControl, wifi: wifiControl, vol: volControl, bri: briControl,
            oci: ociControl, disk: diskControl, ntf: ntfControl,
            clock: bar.plan.centred ? clockCentre : clockRight,
            more: moreControl
        })[name];
        const xOf = function (it) { return it.parent === rightGroup ? rightGroup.x + it.x : it.x; };
        if (bar.plan.overflow.indexOf(name) >= 0 && moreControl.visible) return xOf(moreControl);
        if (item && item.visible && item.width > 0) return xOf(item);
        return -1;
    }

    // What the » menu shows for a control that moved into it.
    function iconFor(id) {
        return ({ bt: "bluetooth", wifi: bar.wifiRadioOff ? "wifi-0" : "wifi-" + bar.wifiLevel,
                  vol: bar.volIcon, bri: "brightness", oci: "cloud", disk: "disk", ntf: "bell" })[id] || "";
    }

    function valueFor(id) {
        if (id === "bt") return !bar.btOn ? "Off" : bar.btCount > 0 ? bar.btCount + " connected" : "On";
        if (id === "wifi") return bar.wifi.statusText;
        if (id === "vol") return bar.sound.muted ? "Muted" : bar.sound.volumePercent + "%";
        if (id === "bri") return bar.brightness.shownLevel + "%";
        if (id === "oci") return bar.oci.state === "ready"
            ? bar.ociRows.map(function (r) { return r.value; }).join(" ") : bar.oci.stateText;
        if (id === "disk") return bar.storage.label.replace(/^Disks /, "");
        if (id === "ntf") return bar.ntfWide;
        return "";
    }

    //----------------------------------------------------------------
    // State the bar draws
    //----------------------------------------------------------------
    readonly property int inGap: 6

    readonly property bool btPresent: bluetooth.adapter !== null
    readonly property bool btOn: btPresent && bluetooth.adapter.enabled
    readonly property int btCount: bluetooth.connectedCount

    readonly property bool wifiPresent: wifi.device !== null
    readonly property bool wifiRadioOff: !wifi.radioEnabled || !wifi.hardwareEnabled
    // Four rungs, so one bar is a quarter of the scale. Zero bars is the
    // radio on with no link; a slashed icon is the radio off.
    readonly property int wifiLevel: {
        if (!wifi.connectedNetwork) return 0;
        const s = wifi.connectedNetwork.signalStrength;
        return s >= 0.75 ? 4 : s >= 0.5 ? 3 : s >= 0.25 ? 2 : 1;
    }

    readonly property bool volPresent: sound.available
    readonly property string volIcon: sound.muted ? "volume-muted"
        : sound.volumePercent <= 0 ? "volume-0"
        : sound.volumePercent <= 50 ? "volume-1" : "volume-2"

    readonly property var ociRows: oci.rows.map(function (row) { return OciModel.rowRule(row); })

    readonly property string ntfNarrow: NotificationModel.barText(notifications.view,
        notifications.status, notifications.count, false).replace(/^NTF ?/, "")
    readonly property string ntfWide: NotificationModel.barText(notifications.view,
        notifications.status, notifications.count, true).replace(/^Notifications ?/, "")
    readonly property string ntfNumber: (/^\d+\+?/.exec(ntfNarrow) || [""])[0]
    readonly property string ntfSuffix: {
        // What the wide text adds after the count: ", local only",
        // ", sync error", or "offline".
        const rest = ntfWide.replace(/^\d+\+?/, "");
        return rest;
    }
    readonly property string ntfTone: NotificationModel.barTone(notifications.view,
        notifications.status, notifications.items)

    readonly property var batteryRule: BatteryRule.rule(battery.percent, battery.charging,
        battery.full, battery.onBattery)

    readonly property string appId: {
        const w = bar.frontWindow;
        const wl = w ? w.wayland : null;
        return wl && wl.appId ? wl.appId : "";
    }
    readonly property var appEntry: {
        // Read applications so the lookup runs again once entries load.
        DesktopEntries.applications.values;
        return appId !== "" ? DesktopEntries.heuristicLookup(appId) : null;
    }
    readonly property string appName: appEntry && appEntry.name ? appEntry.name : appId
    readonly property string appIcon: appEntry && appEntry.icon ? appEntry.icon : appId

    readonly property string title: frontWindow ? (frontWindow.title || "") : ""

    readonly property string dictationText: {
        let value = dictation.statusText;
        if (dictation.backendLabel !== "") value += " · " + dictation.backendLabel;
        if (dictation.queueCount > 1) value += " · " + dictation.queueText;
        return value;
    }

    function clockTime(date) {
        const hour = date.getHours() % 12 || 12;
        return hour + Qt.formatDateTime(date, ":mm");
    }
    readonly property string clockDate: Qt.formatDateTime(now, "M/d")

    //----------------------------------------------------------------
    // The plan
    //----------------------------------------------------------------
    // Raw content widths, as bar-plan.js wants them: an icon alone, a
    // readout's text box alone. The planner adds every pad and every gap
    // (the 6 px between icon and readout included), so none is counted here.
    readonly property real numW: PlatinumMetrics.widest(["100", PlatinumMetrics.digits(2)])
    readonly property real clockTimeW: PlatinumMetrics.widest(["12:" + PlatinumMetrics.digits(2),
        "10:" + PlatinumMetrics.digits(2), PlatinumMetrics.digits(1) + ":" + PlatinumMetrics.digits(2)])
    readonly property real clockDateW: PlatinumMetrics.widest(["12/" + PlatinumMetrics.digits(2),
        "10/" + PlatinumMetrics.digits(2), PlatinumMetrics.digits(1) + "/" + PlatinumMetrics.digits(2)])
    readonly property real clockGap: PlatinumMetrics.width("  ")
    readonly property bool diskCounting: storage.state === "ready" && storage.issues.length > 0
    readonly property bool ntfOffline: notifications.view.kind === "offline"

    readonly property var metrics: ({
        controls: [
            btPresent ? { id: "bt", iconWidth: 16,
                readoutWidth: btCount > 0 ? btCountBox.width : 0 } : null,
            wifiPresent ? { id: "wifi", iconWidth: 16, readoutWidth: 0 } : null,
            volPresent ? { id: "vol", iconWidth: 16, readoutWidth: numW } : null,
            brightness.available ? { id: "bri", iconWidth: 16, readoutWidth: numW } : null,
            oci.enabled ? { id: "oci", iconWidth: 16, readoutWidth: ociFull.implicitWidth } : null,
            // When the label yields, the issue count keeps its fixed box.
            storage.enabled ? { id: "disk", iconWidth: 16, readoutWidth: diskFull.implicitWidth,
                compactReadoutWidth: diskCounting ? diskCountBox.width : 0 } : null,
            // When the count yields it becomes a dot on the bell; offline
            // keeps a "!".
            { id: "ntf", iconWidth: 16,
                readoutWidth: ntfNumber !== "" || ntfSuffix !== "" ? ntfFull.implicitWidth : 0,
                compactReadoutWidth: ntfOffline ? ntfCompact.implicitWidth : 0 }
        ].filter(function (c) { return c !== null; }),
        markWidth: 20,
        // The title box draws 8 px either side of its text; the dictation
        // row's implicit width already holds its own spacing.
        titleWidth: dictation.barVisible ? dictationRow.implicitWidth
            : title !== "" ? PlatinumMetrics.width(title) + 16 : 0,
        titleMinWidth: dictation.barVisible ? dictationRow.minimumWidth : 96,
        clockWidth: clockDateW + clockGap + clockTimeW,
        clockTimeWidth: clockTimeW,
        chordWidth: chordVisible ? chord.implicitWidth : 0,
        // The battery is the planner's one whole-content width: icon, the
        // 6 px between, and the percent box, because it never splits.
        batteryWidth: battery.present ? 18 + inGap + batteryBox.width : 0,
        appIconWidth: appId !== "" ? 16 : 0,
        appNameWidth: appId !== "" ? PlatinumMetrics.width(appName) : 0,
        overflowWidth: 16
    })

    readonly property var plan: BarPlan.plan(bar.width, bar.metrics)
    readonly property real pad: plan.pad
    function onBar(id) { return plan.controls.indexOf(id) >= 0; }

    //----------------------------------------------------------------
    // Drawing
    //----------------------------------------------------------------
    Rectangle {
        id: surface
        anchors.fill: parent
        color: Theme.barSurface

        // A press on the bar outside a control closes an open menu.
        MouseArea {
            anchors.fill: parent
            onPressed: if (bar.menuHere) MenuState.close()
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Theme.hair
            color: Theme.barRule
        }
    }

    // The screen's top corners, cut in the screen's black.
    Repeater {
        model: [0, 1]
        Canvas {
            required property int modelData
            width: 8
            height: 8
            x: modelData === 0 ? 0 : bar.width - 8
            y: 0
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.fillStyle = "#000000";
                c.beginPath();
                if (modelData === 0) {
                    c.moveTo(0, 0); c.lineTo(8, 0); c.arc(8, 8, 8, -Math.PI / 2, Math.PI, true); c.closePath();
                } else {
                    c.moveTo(8, 0); c.lineTo(8, 8); c.arc(0, 8, 8, 0, -Math.PI / 2, true); c.closePath();
                }
                c.fill();
            }
        }
    }

    // ---------------------------------------------------------- left
    Row {
        id: leftGroup
        x: 6
        height: Theme.barHeight - Theme.hair
        // The plan's budget for the whole left group; the title elides
        // inside it, so it never runs under the clock or the chord.
        width: Math.max(0, bar.plan.leftMax - x)
        clip: true

        BarControl {
            id: markControl
            screen: bar.modelData
            pad: bar.pad
            icon: "mark"
            iconWidth: 20
            iconHeight: 18
            onActivated: {
                MenuState.close();
                bar.omniBar.enterRoot();
            }
        }

        Item {
            id: titleBox
            visible: !bar.dictation.barVisible && bar.plan.show.title
            height: parent.height
            width: Math.max(0, Math.min(titleText.implicitWidth + 16, leftGroup.width - markControl.width))

            Text {
                id: titleText
                x: 8
                width: parent.width - 16
                anchors.verticalCenter: parent.verticalCenter
                text: bar.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.barTextSecondary
                font.family: Theme.platinumFont
                font.pixelSize: Theme.platinumText
                font.letterSpacing: Theme.platinumTracking
            }
        }

        // Dictation replaces the title while it matters. Retry and Dismiss
        // are controls, so the text yields to them, never the reverse.
        Item {
            id: dictationRow
            visible: bar.dictation.barVisible
            height: parent.height
            readonly property real buttonsWidth: (retryButton.visible ? retryButton.width + 6 : 0)
                + (dismissButton.visible ? dismissButton.width + 6 : 0)
            readonly property real minimumWidth: 8 + 8 + 8 + 60 + buttonsWidth
            implicitWidth: 8 + 8 + 8 + dictationLabel.implicitWidth + 8 + buttonsWidth
            width: Math.max(0, Math.min(implicitWidth, leftGroup.width - markControl.width))

            Rectangle {
                id: dictationDot
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                // Recording and failure are the danger tone. Working is a
                // status at rest, so it takes the text colour.
                color: bar.dictation.state === "working" ? Theme.barText : Theme.barDanger
            }

            Text {
                id: dictationLabel
                x: dictationDot.x + 8 + 8
                width: Math.max(0, dictationRow.width - x - 8 - dictationRow.buttonsWidth)
                anchors.verticalCenter: parent.verticalCenter
                text: bar.dictationText
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: bar.dictation.state === "failed" ? Theme.barDanger : Theme.barText
                font.family: Theme.platinumFont
                font.pixelSize: Theme.platinumText
                font.letterSpacing: Theme.platinumTracking
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                PlatinumButton {
                    id: retryButton
                    onBar: true
                    visible: bar.dictation.state === "failed" && bar.dictation.canRetry
                    text: "Retry"
                    fixedWidth: PlatinumMetrics.buttonWidth(["Retry", "Dismiss"])
                    onClicked: bar.dictation.retryFailed()
                }

                PlatinumButton {
                    id: dismissButton
                    onBar: true
                    visible: bar.dictation.state === "failed"
                    text: "Dismiss"
                    fixedWidth: PlatinumMetrics.buttonWidth(["Retry", "Dismiss"])
                    onClicked: bar.dictation.dismissFailure()
                }
            }
        }
    }

    // ---------------------------------------------------------- centre
    // The clock sits in the middle of the bar. Once the bar is too narrow
    // it leaves the centre for the right group, the Mac OS 8 place. A
    // click opens the clock menu with the full date.
    component ClockTitle: BarControl {
        id: clockTitle
        screen: bar.modelData
        menu: "clock"
        open: bar.isOpen("clock")
        pad: bar.pad
        iconWidth: 0
        iconHeight: 0

        Text {
            width: bar.plan.show.clockDate ? bar.clockDateW + bar.clockGap + bar.clockTimeW : bar.clockTimeW
            horizontalAlignment: Text.AlignHCenter
            text: bar.plan.show.clockDate
                ? bar.clockDate + "  " + bar.clockTime(bar.now)
                : bar.clockTime(bar.now)
            color: clockTitle.fg
            font.family: Theme.platinumFont
            font.pixelSize: Theme.platinumText
            font.letterSpacing: Theme.platinumTracking
        }
    }

    ClockTitle {
        id: clockCentre
        visible: !bar.chordVisible && bar.plan.centred
        x: PlatinumMetrics.even(bar.width / 2 - width / 2)
    }

    // The Super+O chord: each key as a key cap, then what it opens. When
    // the full hint does not fit beside the title and the controls, the
    // names drop and the key caps stay.
    Row {
        id: chord
        visible: bar.chordVisible
        x: PlatinumMetrics.even(bar.width / 2 - width / 2)
        height: Theme.barHeight - Theme.hair
        spacing: 0
        readonly property var keys: {
            const k = [["B", "Bluetooth"], ["W", "Wi-Fi"], ["S", "Sound"], ["L", "Brightness"]];
            if (bar.oci.enabled) k.push(["C", "Cloud"]);
            if (bar.storage.enabled) k.push(["D", "Disks"]);
            k.push(["Esc", "cancel"]);
            return k;
        }
        readonly property real fullWidth: {
            let w = 20;
            for (const k of keys) w += PlatinumMetrics.smallWidth(k[0]) + 8 + 6 + PlatinumMetrics.width(k[1]) + 14;
            return w;
        }
        readonly property bool compact: fullWidth > bar.width * 0.5

        Item { width: 10; height: 1 }

        Repeater {
            model: chord.keys

            Row {
                required property var modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                rightPadding: chord.compact ? 6 : 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(18, keyText.implicitWidth + 8)
                    height: 18
                    radius: 3
                    color: "transparent"
                    border.width: Theme.hair
                    border.color: Theme.barText

                    Text {
                        id: keyText
                        anchors.centerIn: parent
                        text: modelData[0]
                        color: Theme.barText
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                    }
                }

                Text {
                    visible: !chord.compact
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[1]
                    color: Theme.barText
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumText
                    font.letterSpacing: Theme.platinumTracking
                }
            }
        }
    }

    // ---------------------------------------------------------- right
    Row {
        id: rightGroup
        anchors.right: parent.right
        anchors.rightMargin: 6
        height: Theme.barHeight - Theme.hair
        spacing: bar.plan.gap
        layoutDirection: Qt.LeftToRight

        ClockTitle {
            id: clockRight
            visible: !bar.chordVisible && !bar.plan.centred
        }

        BarControl {
            id: btControl
            visible: bar.btPresent && bar.onBar("bt")
            screen: bar.modelData
            menu: "bt"
            open: bar.isOpen("bt")
            pad: bar.pad
            icon: "bluetooth"
            slashed: !bar.btOn

            BarNumber {
                id: btCountBox
                visible: bar.btCount > 0 && bar.plan.show.btCount
                widest: ["8", PlatinumMetrics.digits(1)]
                text: String(bar.btCount)
                tone: btControl.fg
            }
        }

        BarControl {
            id: wifiControl
            visible: bar.wifiPresent && bar.onBar("wifi")
            screen: bar.modelData
            menu: "wifi"
            open: bar.isOpen("wifi")
            pad: bar.pad
            icon: bar.wifiRadioOff ? "wifi-0" : "wifi-" + bar.wifiLevel
            slashed: bar.wifiRadioOff
        }

        BarControl {
            id: volControl
            visible: bar.volPresent && bar.onBar("vol")
            screen: bar.modelData
            menu: "vol"
            open: bar.isOpen("vol")
            pad: bar.pad
            icon: bar.volIcon

            BarNumber {
                visible: bar.plan.show.volumeNumber
                width: bar.numW
                text: bar.sound.muted ? "--" : String(bar.sound.volumePercent)
                tone: volControl.fg
            }
        }

        BarControl {
            id: briControl
            visible: bar.brightness.available && bar.onBar("bri")
            screen: bar.modelData
            menu: "bri"
            open: bar.isOpen("bri")
            pad: bar.pad
            icon: "brightness"
            onWheel: function (delta) { if (delta !== 0) bar.brightness.step(delta > 0 ? 1 : -1); }

            BarNumber {
                visible: bar.plan.show.brightnessNumber
                width: bar.numW
                text: String(bar.brightness.shownLevel)
                tone: briControl.fg
            }

        }

        BarControl {
            id: ociControl
            visible: bar.oci.enabled && bar.onBar("oci")
            screen: bar.modelData
            menu: "oci"
            open: bar.isOpen("oci")
            pad: bar.pad
            icon: "cloud"
            tone: Theme.barTone(bar.oci.tone)

            Row {
                id: ociFull
                visible: bar.plan.show.ociLabel

                Text {
                    visible: bar.oci.state !== "ready"
                    text: bar.oci.state === "unavailable" ? "--" : bar.oci.state === "loading" ? "..." : "!"
                    color: ociControl.fg
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumText
                }

                Repeater {
                    model: bar.oci.state === "ready" ? bar.ociRows : []

                    Row {
                        required property var modelData
                        required property int index

                        Text {
                            text: (index > 0 ? " " : "") + modelData.name + ":"
                            color: ociControl.inverted ? ociControl.fg : Theme.barText
                            font.family: Theme.platinumFont
                            font.pixelSize: Theme.platinumText
                            font.letterSpacing: Theme.platinumTracking
                        }

                        // Each profile in its own tone.
                        BarNumber {
                            widest: ["100.0%", PlatinumMetrics.digits(3) + ".0%", "Failed"]
                            text: modelData.value
                            tone: ociControl.inverted ? ociControl.fg : Theme.barTone(modelData.tone)
                        }
                    }
                }
            }
        }

        BarControl {
            id: diskControl
            visible: bar.storage.enabled && bar.onBar("disk")
            screen: bar.modelData
            menu: "disk"
            open: bar.isOpen("disk")
            pad: bar.pad
            icon: "disk"
            tone: Theme.barTone(bar.storage.tone)

            readonly property int issues: bar.storage.issues.length
            readonly property bool counting: bar.storage.state === "ready" && issues > 0

            Row {
                id: diskFull
                visible: bar.plan.show.diskLabel

                BarNumber {
                    visible: diskControl.counting
                    widest: ["99", PlatinumMetrics.digits(2)]
                    text: String(diskControl.issues)
                    tone: diskControl.fg
                }
                Text {
                    text: diskControl.counting ? (diskControl.issues === 1 ? " issue" : " issues")
                        : bar.storage.label.replace(/^Disks /, "")
                    color: diskControl.fg
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumText
                    font.letterSpacing: Theme.platinumTracking
                }
            }

            // When the label yields, the count stays in its fixed box.
            Row {
                id: diskCompact
                visible: !bar.plan.show.diskLabel && diskControl.counting
                BarNumber {
                    id: diskCountBox
                    visible: diskControl.counting
                    widest: ["99", PlatinumMetrics.digits(2)]
                    text: String(diskControl.issues)
                    tone: diskControl.fg
                }
            }
        }

        BarControl {
            id: ntfControl
            visible: bar.onBar("ntf")
            screen: bar.modelData
            menu: "ntf"
            open: bar.isOpen("ntf")
            pad: bar.pad
            icon: "bell"
            tone: ({ danger: Theme.barDanger, warning: Theme.barWarning,
                     primary: Theme.barText, muted: Theme.barTextOff })[bar.ntfTone] || Theme.barText

            Row {
                id: ntfFull
                visible: bar.plan.show.notificationCount && (bar.ntfNumber !== "" || bar.ntfSuffix !== "")

                // The count keeps its fixed box. With a suffix the digits sit
                // at the box's right end, next to ", local only".
                BarNumber {
                    visible: bar.ntfNumber !== ""
                    widest: ["99+", PlatinumMetrics.digits(2)]
                    horizontalAlignment: bar.ntfSuffix !== "" ? Text.AlignRight : Text.AlignLeft
                    text: bar.ntfNumber
                    tone: ntfControl.fg
                }
                Text {
                    // ", local only", ", sync error" or "offline".
                    visible: text !== ""
                    text: bar.ntfSuffix
                    color: ntfControl.fg
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumText
                    font.letterSpacing: Theme.platinumTracking
                }
            }

            Text {
                id: ntfCompact
                visible: !bar.plan.show.notificationCount && bar.notifications.view.kind === "offline"
                text: "!"
                color: ntfControl.fg
                font.family: Theme.platinumFont
                font.pixelSize: Theme.platinumText
            }

            // The count becomes a dot when it yields.
            iconExtras: Rectangle {
                visible: !bar.plan.show.notificationCount && bar.notifications.count > 0
                x: 11
                y: -1
                width: 7
                height: 7
                radius: 3.5
                color: ntfControl.fg
                border.width: Theme.hair
                border.color: ntfControl.bg
            }
        }

        BarControl {
            id: moreControl
            visible: bar.plan.overflow.length > 0
            screen: bar.modelData
            menu: "more"
            open: bar.isOpen("more") || (bar.menuHere && bar.plan.overflow.indexOf(MenuState.current) >= 0)
            pad: bar.pad
            icon: "more"
        }

        // The battery is a readout with no menu. Its percent never yields.
        BarControl {
            id: batteryControl
            visible: bar.battery.present
            screen: bar.modelData
            hoverable: false
            pad: bar.pad
            icon: "battery"
            iconWidth: 18
            tone: Theme.barTone(bar.batteryRule.tone)

            iconExtras: [
                Rectangle {
                    x: 3
                    y: 6
                    height: 4
                    width: 9.5 * Math.min(1, Math.max(0, bar.battery.percent / 100))
                    color: batteryControl.fg
                },
                PlatinumIcon {
                    anchors.fill: parent
                    visible: bar.batteryRule.indicator !== "none"
                    name: bar.batteryRule.indicator === "plug" ? "plug" : "bolt"
                    color: batteryControl.fg
                    knock: batteryControl.bg
                }
            ]

            BarNumber {
                id: batteryBox
                widest: ["100%", PlatinumMetrics.digits(2) + "%"]
                text: bar.battery.percent + "%"
                tone: batteryControl.fg
            }
        }

        // The front app: its icon and name, a way into the omni bar's
        // window list. The name is the first readout to yield.
        BarControl {
            id: appControl
            visible: bar.appId !== ""
            screen: bar.modelData
            pad: bar.pad
            icon: ""
            onActivated: {
                MenuState.close();
                bar.omniBar.enterMode("window");
            }

            iconExtras: IconImage {
                anchors.fill: parent
                implicitSize: 16
                source: bar.appIcon !== "" ? Quickshell.iconPath(bar.appIcon, "application-x-executable") : ""
            }

            Text {
                visible: bar.plan.show.appName
                text: bar.appName
                textFormat: Text.PlainText
                color: appControl.fg
                font.family: Theme.platinumFont
                font.pixelSize: Theme.platinumText
                font.letterSpacing: Theme.platinumTracking
            }
        }
    }
}
