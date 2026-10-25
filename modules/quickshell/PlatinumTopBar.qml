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
    // The remote-builder gate (BuilderGate.qml), on hosts that have one.
    property var builderGate: null
    readonly property bool builderPresent: !!builderGate && builderGate.enabled === true
    property var frontWindow: null
    // The shared Beszel owner (panels/Beszel.qml), where the shell has one.
    property var beszel: null
    readonly property bool fleetPresent: beszel !== null
    readonly property var fleetReadout: fleetPresent ? beszel.readout : ({shape: "down", tone: "muted", text: ""})
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
    implicitHeight: PlatinumTokens.barHeight
    color: "transparent"

    onDevicePixelRatioChanged: if (devicePixelRatio > 0) PlatinumTokens.pixelRatio = devicePixelRatio
    Component.onCompleted: if (devicePixelRatio > 0) PlatinumTokens.pixelRatio = devicePixelRatio

    readonly property bool menuHere: MenuState.current !== "" && MenuState.screen === bar.modelData
    function isOpen(name) { return bar.menuHere && MenuState.current === name; }

    // Where a menu hangs: under its control, under » when the control
    // overflowed, or -1 (top right) when the bar does not show it.
    // It reads x through the parents, not mapToItem, so a binding that
    // calls it follows the bar when its layout changes under an open menu.
    function anchorFor(name) {
        const item = ({
            apple: markControl, app: appControl,
            bt: btControl, wifi: wifiControl, vol: volControl, bri: briControl,
            oci: ociControl, disk: diskControl, fleet: fleetControl, builder: builderControl, ntf: ntfControl,
            clock: bar.plan.centred ? clockCentre : clockRight,
            more: moreControl
        })[name];
        const xOf = function (it) { return it.parent === rightGroup ? rightGroup.x + it.x : it.x; };
        if (bar.plan.overflow.indexOf(name) >= 0 && moreControl.visible) return xOf(moreControl);
        if (item && item.visible && item.width > 0) return xOf(item);
        return -1;
    }

    // A control's place and width on the bar ({x, w}), or »'s when it
    // overflowed; null when the bar does not show it. The glance space's
    // zoom rects start here.
    function controlRect(name) {
        const x = bar.anchorFor(name);
        if (x < 0) return null;
        const item = bar.plan.overflow.indexOf(name) >= 0 ? moreControl : ({ fleet: fleetControl })[name];
        return {x: x, w: item ? item.width : 16};
    }

    // The right end of a title, for a menu that hangs from its right end:
    // the Application menu, at the right end of the bar, as in Mac OS 8.5.
    function anchorRightFor(name) {
        if (name !== "app" || !appControl.visible || appControl.width <= 0) return -1;
        return rightGroup.x + appControl.x + appControl.width;
    }

    // What the » menu shows for a control that moved into it.
    function iconFor(id) {
        return ({ bt: "bluetooth", wifi: bar.wifiRadioOff ? "wifi-0" : "wifi-" + bar.wifiLevel,
                  vol: bar.volIcon, bri: "brightness", oci: "cloud", disk: "disk", builder: "builder",
                  ntf: "bell" })[id] || "";
    }

    function valueFor(id) {
        if (id === "bt") return !bar.btOn ? "Off" : bar.btCount > 0 ? bar.btCount + " connected" : "On";
        if (id === "wifi") return bar.wifi.statusText;
        if (id === "vol") return bar.sound.muted ? "Muted" : bar.sound.volumePercent + "%";
        if (id === "bri") return bar.brightness.shownLevel + "%";
        if (id === "oci") return bar.oci.state === "ready"
            ? bar.ociRows.map(function (r) { return r.value; }).join(" ") : bar.oci.stateText;
        if (id === "disk") return bar.storage.label.replace(/^Disks /, "");
        if (id === "fleet") return bar.fleetPresent ? bar.beszel.fleet.state === "ready"
            ? (bar.beszel.fleet.problems.length ? bar.beszel.fleet.problems.length + (bar.beszel.fleet.problems.length === 1 ? " problem" : " problems") : "ok")
            : bar.beszel.fleet.state === "loading" ? "..." : "--" : "";
        if (id === "ntf") return bar.ntfWide;
        if (id === "builder") return builderControl.fullText;
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
    // Retry and Dismiss share one width. Their group is the buttons and
    // the gap between them, nothing before.
    readonly property real dictationButtonW: PlatinumMetrics.buttonWidth(["Retry", "Dismiss"])
    readonly property bool dictationFailed: dictation.barVisible && dictation.state === "failed"
    readonly property real dictationActionsW: !dictationFailed ? 0
        : dictation.canRetry ? 2 * dictationButtonW + inGap : dictationButtonW
    readonly property bool dictationOverflowed: plan.overflow.indexOf("dictation") >= 0
    readonly property bool showDictationActions: dictationFailed && !dictationOverflowed
        && plan.show.dictationActions !== false

    readonly property bool diskCounting: storage.state === "ready" && storage.issues.length > 0
    readonly property bool ntfOffline: notifications.view.kind === "offline"

    // Readout widths come from the strings the bar draws, not from the
    // drawn items: an item's implicit width settles one layout pass late,
    // and the plan must never see a full readout narrower than its compact
    // one.
    readonly property var ociBoxText: ["100.0%", PlatinumMetrics.digits(3) + ".0%", "Failed"]
    readonly property string ociStateMark: oci.state === "unavailable" ? "--" : oci.state === "loading" ? "..." : "!"
    readonly property real ociReadoutW: {
        if (oci.state !== "ready") return PlatinumMetrics.width(ociStateMark);
        let w = 0;
        for (let i = 0; i < ociRows.length; i++)
            w += PlatinumMetrics.width((i > 0 ? " " : "") + ociRows[i].name + ":") + PlatinumMetrics.widest(ociBoxText);
        return w;
    }
    readonly property var diskBoxText: ["99", PlatinumMetrics.digits(2)]
    readonly property string diskWord: diskCounting ? (storage.issues.length === 1 ? " issue" : " issues")
        : storage.label.replace(/^Disks /, "")
    readonly property real diskReadoutW: (diskCounting ? PlatinumMetrics.widest(diskBoxText) : 0)
        + PlatinumMetrics.width(diskWord)
    readonly property var ntfBoxText: ["99+", PlatinumMetrics.digits(2)]
    readonly property var fleetBoxText: ["99", PlatinumMetrics.digits(2), "--"]
    readonly property real fleetReadoutW: fleetReadout.text !== "" ? PlatinumMetrics.widest(fleetBoxText) : 0
    readonly property real ntfReadoutW: (ntfNumber !== "" ? PlatinumMetrics.widest(ntfBoxText) : 0)
        + (ntfSuffix !== "" ? PlatinumMetrics.width(ntfSuffix) : 0)

    readonly property var metrics: ({
        controls: [
            btPresent ? { id: "bt", iconWidth: 16,
                readoutWidth: btCount > 0 ? btCountBox.width : 0 } : null,
            wifiPresent ? { id: "wifi", iconWidth: 16, readoutWidth: 0 } : null,
            volPresent ? { id: "vol", iconWidth: 16, readoutWidth: numW } : null,
            brightness.available ? { id: "bri", iconWidth: 16, readoutWidth: numW } : null,
            oci.enabled ? { id: "oci", iconWidth: 16, readoutWidth: ociReadoutW } : null,
            // When the label yields, the issue count keeps its fixed box.
            storage.enabled ? { id: "disk", iconWidth: 16, readoutWidth: diskReadoutW,
                compactReadoutWidth: diskCounting ? PlatinumMetrics.widest(diskBoxText) : 0 } : null,
            // Fleet: a light, and a count only when there are problems. When
            // the count yields the light stays; the Glance menu's header
            // keeps the summary.
            fleetPresent ? { id: "fleet", iconWidth: 12, readoutWidth: fleetReadoutW, compactReadoutWidth: 0 } : null,
            // The builder's words yield to its running count alone.
            builderPresent ? { id: "builder", iconWidth: 16, readoutWidth: builderControl.fullWidth,
                compactReadoutWidth: builderControl.compactWidth } : null,
            // When the count yields it becomes a dot on the bell; offline
            // keeps a "!".
            { id: "ntf", iconWidth: 16,
                readoutWidth: ntfReadoutW,
                compactReadoutWidth: ntfOffline ? Math.min(PlatinumMetrics.width("!"), ntfReadoutW) : 0 }
        ].filter(function (c) { return c !== null; }),
        markWidth: 20,
        // The title box draws 8 px either side of its text. While dictation
        // shows, the title is its dot and status text and ends at the
        // text; Retry and Dismiss are dictationActionsWidth, and the
        // planner adds the 6 px before them.
        titleWidth: dictation.barVisible ? 8 + 8 + 8 + PlatinumMetrics.width(dictationText)
            : title !== "" ? PlatinumMetrics.width(title) + 16 : 0,
        titleMinWidth: dictation.barVisible ? 8 + 8 + 8 + 60 : 96,
        dictationActionsWidth: dictationActionsW,
        clockWidth: clockDateW + clockGap + clockTimeW,
        clockTimeWidth: clockTimeW,
        chordWidth: chordVisible ? chord.implicitWidth : 0,
        // The battery is the planner's one whole-content width: icon, the
        // 6 px between, and the percent box, because it never splits.
        batteryWidth: battery.present ? 18 + inGap + batteryBox.width : 0,
        // The Application menu is always on the bar, even with no front
        // app: it is where Show All lives.
        appIconWidth: 16,
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
        color: PlatinumTokens.barSurface

        // A press on the bar outside a control closes an open menu.
        MouseArea {
            anchors.fill: parent
            onPressed: if (bar.menuHere) MenuState.close()
        }

        // The raised Platinum bevel on the light and grey bars: one
        // highlight hair on top, one shade hair just above the rule. The
        // shadow under the bar is PlatinumBarShadow, a window of its own.
        Rectangle {
            visible: PlatinumTokens.barRaised
            anchors.left: parent.left
            anchors.right: parent.right
            y: 0
            height: PlatinumTokens.hair
            color: PlatinumTokens.barBevelLight
        }
        Rectangle {
            visible: PlatinumTokens.barRaised
            anchors.left: parent.left
            anchors.right: parent.right
            y: parent.height - 2 * PlatinumTokens.hair
            height: PlatinumTokens.hair
            color: PlatinumTokens.barBevelDark
        }

        // The rule. Extra dark draws none: the black bar meets the windows.
        Rectangle {
            visible: PlatinumTokens.barRuled
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: PlatinumTokens.hair
            color: PlatinumTokens.barRule
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
    // The mark is a control: it always keeps its full width and is never
    // clipped. The title and the dictation status are readouts and elide
    // in what the plan leaves after it. Retry and Dismiss are controls:
    // they show at full width or move into the » menu, never shrink.
    // The mountain drops the Apple menu, like every other title: inverted
    // while it is open, and part of the sticky hover between titles.
    PlatinumBarControl {
        id: markControl
        x: 6
        screen: bar.modelData
        menu: "apple"
        open: bar.isOpen("apple")
        pad: bar.pad
        icon: "mark"
        iconWidth: 20
        iconHeight: 18
    }

    Item {
        id: leftText
        // The plan's gap between the mark and the title: 2 px, or 0 once
        // spacing has yielded.
        x: markControl.x + markControl.width + bar.plan.gap
        height: PlatinumTokens.barHeight - PlatinumTokens.hair
        // The plan's budget for the whole left group, less the mark.
        width: Math.max(0, bar.plan.leftMax - x)

        Item {
            id: titleBox
            visible: !bar.dictation.barVisible && bar.plan.show.title
            height: parent.height
            width: Math.min(titleText.implicitWidth + 16, leftText.width)

            Text {
                id: titleText
                x: 8
                width: Math.max(0, parent.width - 16)
                anchors.verticalCenter: parent.verticalCenter
                text: bar.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: PlatinumTokens.barTextSecondary
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumText
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }

        // Dictation replaces the title while it matters.
        Item {
            id: dictationRow
            visible: bar.dictation.barVisible
            anchors.fill: parent

            // The dot stays while it fits, even when the words yield, so a
            // failure still shows on the bar.
            Rectangle {
                id: dictationDot
                visible: leftText.width >= 24
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                // Recording and failure are the danger tone. Working is a
                // status at rest, so it takes the text colour.
                color: bar.dictation.state === "working" ? PlatinumTokens.barText : PlatinumTokens.barDanger
            }

            Text {
                id: dictationLabel
                visible: bar.plan.show.title
                x: dictationDot.x + 8 + 8
                // The status gives way to the actions, never the reverse.
                width: Math.max(0, Math.min(implicitWidth, dictationRow.width - x
                    - (bar.showDictationActions ? bar.dictationActionsW + bar.inGap : 0)))
                anchors.verticalCenter: parent.verticalCenter
                text: bar.dictationText
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: bar.dictation.state === "failed" ? PlatinumTokens.barDanger : PlatinumTokens.barText
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumText
                font.letterSpacing: PlatinumTokens.platinumTracking
            }

            Row {
                id: dictationActions
                visible: bar.showDictationActions
                // Exactly 6 px after the status text, only while inline.
                x: dictationLabel.visible ? dictationLabel.x + dictationLabel.width + bar.inGap : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: bar.inGap

                PlatinumButton {
                    onBar: true
                    visible: bar.dictation.canRetry
                    text: "Retry"
                    fixedWidth: bar.dictationButtonW
                    onClicked: bar.dictation.retryFailed()
                }

                PlatinumButton {
                    onBar: true
                    text: "Dismiss"
                    fixedWidth: bar.dictationButtonW
                    onClicked: bar.dictation.dismissFailure()
                }
            }
        }
    }

    // ---------------------------------------------------------- centre
    // The clock sits in the middle of the bar. Once the bar is too narrow
    // it leaves the centre for the right group, the Mac OS 8 place. A
    // click opens the clock menu with the full date.
    component ClockTitle: PlatinumBarControl {
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
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumText
            font.letterSpacing: PlatinumTokens.platinumTracking
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
        height: PlatinumTokens.barHeight - PlatinumTokens.hair
        spacing: 0
        readonly property var keys: {
            const k = [["B", "Bluetooth"], ["W", "Wi-Fi"], ["S", "Sound"], ["L", "Brightness"]];
            if (bar.oci.enabled) k.push(["C", "Cloud"]);
            if (bar.storage.enabled) k.push(["D", "Disks"]);
            if (bar.fleetPresent) k.push(["F", "Fleet"]);
            if (bar.builderPresent) k.push(["R", "Builder"]);
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
                    border.width: PlatinumTokens.hair
                    border.color: PlatinumTokens.barText

                    Text {
                        id: keyText
                        anchors.centerIn: parent
                        text: modelData[0]
                        color: PlatinumTokens.barText
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                    }
                }

                Text {
                    visible: !chord.compact
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[1]
                    color: PlatinumTokens.barText
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumText
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
            }
        }
    }

    // ---------------------------------------------------------- right
    Row {
        id: rightGroup
        anchors.right: parent.right
        anchors.rightMargin: 6
        height: PlatinumTokens.barHeight - PlatinumTokens.hair
        spacing: bar.plan.gap
        layoutDirection: Qt.LeftToRight

        ClockTitle {
            id: clockRight
            visible: !bar.chordVisible && !bar.plan.centred
        }

        PlatinumBarControl {
            id: btControl
            visible: bar.btPresent && bar.onBar("bt")
            screen: bar.modelData
            menu: "bt"
            open: bar.isOpen("bt")
            pad: bar.pad
            icon: "bluetooth"
            slashed: !bar.btOn

            PlatinumBarNumber {
                id: btCountBox
                visible: bar.btCount > 0 && bar.plan.show.btCount
                widest: ["8", PlatinumMetrics.digits(1)]
                text: String(bar.btCount)
                tone: btControl.fg
            }
        }

        PlatinumBarControl {
            id: wifiControl
            visible: bar.wifiPresent && bar.onBar("wifi")
            screen: bar.modelData
            menu: "wifi"
            open: bar.isOpen("wifi")
            pad: bar.pad
            icon: bar.wifiRadioOff ? "wifi-0" : "wifi-" + bar.wifiLevel
            slashed: bar.wifiRadioOff
        }

        PlatinumBarControl {
            id: volControl
            visible: bar.volPresent && bar.onBar("vol")
            screen: bar.modelData
            menu: "vol"
            open: bar.isOpen("vol")
            pad: bar.pad
            icon: bar.volIcon

            PlatinumBarNumber {
                visible: bar.plan.show.volumeNumber
                width: bar.numW
                text: bar.sound.muted ? "--" : String(bar.sound.volumePercent)
                tone: volControl.fg
            }
        }

        PlatinumBarControl {
            id: briControl
            visible: bar.brightness.available && bar.onBar("bri")
            screen: bar.modelData
            menu: "bri"
            open: bar.isOpen("bri")
            pad: bar.pad
            icon: "brightness"
            onWheel: function (delta) { if (delta !== 0) bar.brightness.step(delta > 0 ? 1 : -1); }

            PlatinumBarNumber {
                visible: bar.plan.show.brightnessNumber
                width: bar.numW
                text: String(bar.brightness.shownLevel)
                tone: briControl.fg
            }

        }

        PlatinumBarControl {
            id: ociControl
            visible: bar.oci.enabled && bar.onBar("oci")
            screen: bar.modelData
            menu: "oci"
            open: bar.isOpen("oci")
            pad: bar.pad
            icon: "cloud"
            tone: PlatinumTokens.barTone(bar.oci.tone)

            Row {
                id: ociFull
                visible: bar.plan.show.ociLabel

                Text {
                    visible: bar.oci.state !== "ready"
                    text: bar.ociStateMark
                    color: ociControl.fg
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumText
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }

                Repeater {
                    model: bar.oci.state === "ready" ? bar.ociRows : []

                    Row {
                        required property var modelData
                        required property int index

                        Text {
                            text: (index > 0 ? " " : "") + modelData.name + ":"
                            color: ociControl.inverted ? ociControl.fg : PlatinumTokens.barText
                            font.family: PlatinumTokens.platinumFont
                            font.pixelSize: PlatinumTokens.platinumText
                            font.letterSpacing: PlatinumTokens.platinumTracking
                        }

                        // Each profile in its own tone.
                        PlatinumBarNumber {
                            widest: bar.ociBoxText
                            text: modelData.value
                            tone: ociControl.inverted ? ociControl.fg : PlatinumTokens.barTone(modelData.tone)
                        }
                    }
                }
            }
        }

        PlatinumBarControl {
            id: diskControl
            visible: bar.storage.enabled && bar.onBar("disk")
            screen: bar.modelData
            menu: "disk"
            open: bar.isOpen("disk")
            pad: bar.pad
            icon: "disk"
            tone: PlatinumTokens.barTone(bar.storage.tone)

            readonly property int issues: bar.storage.issues.length
            readonly property bool counting: bar.storage.state === "ready" && issues > 0

            Row {
                id: diskFull
                visible: bar.plan.show.diskLabel

                PlatinumBarNumber {
                    visible: diskControl.counting
                    widest: bar.diskBoxText
                    text: String(diskControl.issues)
                    tone: diskControl.fg
                }
                Text {
                    text: bar.diskWord
                    color: diskControl.fg
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumText
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
            }

            // When the label yields, the count stays in its fixed box.
            Row {
                id: diskCompact
                visible: !bar.plan.show.diskLabel && diskControl.counting
                PlatinumBarNumber {
                    id: diskCountBox
                    visible: diskControl.counting
                    widest: bar.diskBoxText
                    text: String(diskControl.issues)
                    tone: diskControl.fg
                }
            }
        }

        // The Fleet readout: a quiet status light, a count only when hosts
        // have problems, "--" without data. It is the Glance menu's title.
        PlatinumBarControl {
            id: fleetControl
            visible: bar.fleetPresent && bar.onBar("fleet")
            screen: bar.modelData
            menu: "fleet"
            open: bar.isOpen("fleet")
            pad: bar.pad
            icon: ""
            iconWidth: 12
            iconHeight: 12
            tone: PlatinumTokens.barTone(bar.fleetReadout.tone)

            iconExtras: PlatinumStatusLight {
                anchors.fill: parent
                shape: bar.fleetReadout.shape
                tone: bar.fleetPresent && bar.beszel.stale ? "muted" : bar.fleetReadout.tone
            }

            PlatinumBarNumber {
                visible: bar.fleetReadout.text !== "" && bar.plan.show.fleetCount !== false
                widest: bar.fleetBoxText
                text: bar.fleetReadout.text
                tone: fleetControl.fg
            }
        }

        PlatinumBuilderControl {
            id: builderControl
            gate: bar.builderGate
            visible: bar.builderPresent && bar.onBar("builder")
            screen: bar.modelData
            open: bar.isOpen("builder")
            pad: bar.pad
            showLabel: bar.plan.show.builderLabel !== false
        }

        PlatinumBarControl {
            id: ntfControl
            visible: bar.onBar("ntf")
            screen: bar.modelData
            menu: "ntf"
            open: bar.isOpen("ntf")
            pad: bar.pad
            icon: "bell"
            tone: ({ danger: PlatinumTokens.barDanger, warning: PlatinumTokens.barWarning,
                     primary: PlatinumTokens.barText, muted: PlatinumTokens.barTextOff })[bar.ntfTone] || PlatinumTokens.barText

            Row {
                id: ntfFull
                visible: bar.plan.show.notificationCount && (bar.ntfNumber !== "" || bar.ntfSuffix !== "")

                // The count keeps its fixed box. With a suffix the digits sit
                // at the box's right end, next to ", local only".
                PlatinumBarNumber {
                    visible: bar.ntfNumber !== ""
                    widest: bar.ntfBoxText
                    horizontalAlignment: bar.ntfSuffix !== "" ? Text.AlignRight : Text.AlignLeft
                    text: bar.ntfNumber
                    tone: ntfControl.fg
                }
                Text {
                    // ", local only", ", sync error" or "offline".
                    visible: text !== ""
                    text: bar.ntfSuffix
                    color: ntfControl.fg
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumText
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
            }

            Text {
                id: ntfCompact
                visible: !bar.plan.show.notificationCount && bar.notifications.view.kind === "offline"
                text: "!"
                color: ntfControl.fg
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumText
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
                border.width: PlatinumTokens.hair
                border.color: ntfControl.bg
            }
        }

        PlatinumBarControl {
            id: moreControl
            visible: bar.plan.overflow.length > 0
            screen: bar.modelData
            menu: "more"
            open: bar.isOpen("more") || (bar.menuHere && bar.plan.overflow.indexOf(MenuState.current) >= 0)
            pad: bar.pad
            icon: "more"
        }

        // The battery is a readout with no menu. Its percent never yields.
        PlatinumBarControl {
            id: batteryControl
            visible: bar.battery.present
            screen: bar.modelData
            hoverable: false
            pad: bar.pad
            icon: "battery"
            iconWidth: 18
            tone: PlatinumTokens.barTone(bar.batteryRule.tone)

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

            PlatinumBarNumber {
                id: batteryBox
                widest: ["100%", PlatinumMetrics.digits(2) + "%"]
                text: bar.battery.percent + "%"
                tone: batteryControl.fg
            }
        }

        // The Application menu: the front app's icon and name. It drops the
        // running apps (Hide, Hide Others, Show All, then each app). The name
        // is the first readout to yield. With no front app it shows the
        // desktop mark alone, so Show All stays one click away.
        PlatinumBarControl {
            id: appControl
            screen: bar.modelData
            menu: "app"
            open: bar.isOpen("app")
            pad: bar.pad
            icon: bar.appId !== "" ? "" : "desktop"

            iconExtras: IconImage {
                anchors.fill: parent
                implicitSize: 16
                visible: bar.appId !== ""
                source: bar.appId !== "" && bar.appIcon !== "" ? Quickshell.iconPath(bar.appIcon, "application-x-executable") : ""
            }

            Text {
                visible: bar.plan.show.appName && bar.appId !== ""
                text: bar.appName
                textFormat: Text.PlainText
                color: appControl.fg
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumText
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }
    }
}
