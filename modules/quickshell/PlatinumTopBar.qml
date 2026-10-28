import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick
import "bar-plan.js" as BarPlan
import "app-icon.js" as AppIcon
import "battery.js" as BatteryRule
import "oci-model.js" as OciModel
import "notification-model.js" as NotificationModel

// One screen's top bar, as a Mac OS 8 Platinum menu bar.
//
//   left    the omni mark, then the front window's title or dictation
//   centre  the clock (the time alone), or the Super+O chord while active
//   right   the controls, the battery, the front app
//
// Quiet glyphs: each icon carries its value (speaker waves, sun rays, a
// cloud meter for the worst OCI profile, the battery fill, a dot on the
// bell and on a busy hammer). A number comes onto the bar only in a
// warning or danger tone. Exact values are in Balloon Help (rest the
// pointer on a title) and in each menu's header. A volume or brightness
// change shows its number in a tag under the icon for 1.5 s.
//
// Layout is BarPlan.plan(width, metrics): spacing yields, then readouts
// in one declared order, then controls move into the » menu. A control
// hides only when its hardware is missing.
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
    // Where the front window's title box starts (Go to Address's left edge).
    readonly property real titleX: leftText.x + titleBox.x
    function isOpen(name) { return bar.menuHere && MenuState.current === name; }

    // The bar's titles by name.
    function itemFor(name) {
        return ({
            apple: markControl, find: markControl, app: appControl,
            bt: btControl, wifi: wifiControl, vol: volControl, bri: briControl,
            oci: ociControl, disk: diskControl, fleet: fleetControl, builder: builderControl, ntf: ntfControl,
            battery: batteryControl, chord: chord,
            clock: bar.plan.centred ? clockCentre : clockRight,
            more: moreControl
        })[name] || null;
    }
    function xOf(it) { return it.parent === rightGroup ? rightGroup.x + it.x : it.x; }

    // Where a menu hangs: under its control, under » when the control
    // overflowed, or -1 (top right) when the bar does not show it.
    // It reads x through the parents, not mapToItem, so a binding that
    // calls it follows the bar when its layout changes under an open menu.
    function anchorFor(name) {
        // Go to Address hangs from the front window's title, the window it acts on.
        if (name === "address") return bar.titleX;
        const item = bar.itemFor(name);
        if (bar.plan.overflow.indexOf(name) >= 0 && moreControl.visible) return bar.xOf(moreControl);
        if (item && item.visible && item.width > 0) return bar.xOf(item);
        return -1;
    }

    // A control's place and width on the bar ({x, w}), or »'s when it
    // overflowed; null when the bar does not show it. The glance space's
    // zoom rects, the transient tag and Balloon Help start here.
    function controlRect(name) {
        const x = bar.anchorFor(name);
        if (x < 0) return null;
        const item = bar.plan.overflow.indexOf(name) >= 0 ? moreControl : bar.itemFor(name);
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
                  vol: bar.sound.muted ? "volume-muted" : bar.volIcon, bri: bar.briIcon, oci: "cloud", disk: "disk",
                  builder: "builder", ntf: "bell", apple: "mark", battery: "battery", clock: "", app: "desktop" })[id] || "";
    }

    function valueFor(id) {
        if (id === "battery") return bar.battery.percent + "%";
        if (id === "clock") return Qt.formatDateTime(bar.now, "M/d") + "  " + bar.clockTime(bar.now);
        if (id === "app") return bar.appName;
        if (id === "bt") return !bar.btOn ? "Off" : bar.btCount > 0 ? bar.btCount + " connected" : "On";
        if (id === "wifi") return bar.wifi.statusText;
        if (id === "vol") return bar.sound.muted ? "Muted" : bar.sound.volumePercent + "%";
        if (id === "bri") return bar.briLevel + "%";
        if (id === "oci") return bar.oci.state === "ready"
            ? bar.ociRows.map(function (r) { return r.name + " " + r.value; }).join(", ") : bar.oci.stateText;
        if (id === "disk") return bar.storage.label.replace(/^Disks /, "");
        if (id === "fleet") return bar.fleetPresent ? bar.beszel.fleet.state === "ready"
            ? (bar.beszel.fleet.problems.length ? bar.beszel.fleet.problems.length + (bar.beszel.fleet.problems.length === 1 ? " problem" : " problems") : "ok")
            : bar.beszel.fleet.state === "loading" ? "..." : "--" : "";
        if (id === "ntf") return bar.ntfWide;
        if (id === "builder") return builderControl.fullText;
        return "";
    }

    // Balloon Help: the full value of the title under the pointer, as a
    // sentence (Mac OS 8). Every value here is also in its menu.
    function balloonFor(id) {
        if (id === "clock") return Qt.formatDate(bar.now, "dddd, MMMM d, yyyy") + ".";
        if (id === "oci") return bar.oci.state === "ready"
            ? "OCI egress this month: " + bar.ociRows.map(function (r) { return r.name + " " + r.value; }).join(", ")
                + ". Click for usage in GB."
            : "OCI egress: " + bar.oci.stateText + ".";
        if (id === "bt") return "Bluetooth: " + (!bar.btOn ? "off" : bar.btCount > 0 ? bar.btCount + " connected" : "on, nothing connected") + ".";
        if (id === "wifi") return "Wi-Fi: " + bar.wifi.statusText + ".";
        if (id === "vol") return "Sound: " + (bar.sound.muted ? "muted" : bar.sound.volumePercent + "%") + ".";
        if (id === "bri") return "Brightness: " + bar.briLevel + "%.";
        if (id === "disk") return "Server storage: " + (bar.diskCounting
            ? bar.storage.issues.length + (bar.storage.issues.length === 1 ? " issue" : " issues")
            : bar.storage.state === "ready" ? "ok" : bar.storage.statusText) + ".";
        if (id === "fleet") return "Fleet: " + bar.valueFor("fleet") + ".";
        if (id === "builder") return "Remote builds: " + builderControl.fullText + ".";
        if (id === "ntf") {
            const n = bar.notifications.count;
            const urgent = bar.notifications.items.filter(function (i) { return i.urgency === 2; }).length;
            return "Notifications: " + (n === 0 ? "none" : n + (urgent > 0 ? ", " + urgent + " urgent" : ""))
                + bar.ntfSuffix.replace(/^offline$/, ", offline") + ".";
        }
        if (id === "battery") {
            const b = bar.battery;
            return "Battery: " + b.percent + "%" + (b.onBattery ? (b.charging ? ", charging" : "")
                : b.full ? ", charged" : b.charging ? ", charging" : "") + ".";
        }
        if (id === "app") return bar.appId !== "" ? bar.appName + "." : "No application in front.";
        return "";
    }

    //----------------------------------------------------------------
    // State the bar draws
    //----------------------------------------------------------------
    readonly property int inGap: 6

    readonly property bool btPresent: bluetooth.adapter !== null
    readonly property bool btOn: btPresent && bluetooth.adapter.enabled
    readonly property int btCount: bluetooth.connectedCount
    // On with nothing connected: the rune goes grey. Off: struck through.
    readonly property string btTone: btOn && btCount === 0 ? "muted" : "normal"

    readonly property bool wifiPresent: wifi.device !== null
    readonly property bool wifiRadioOff: !wifi.radioEnabled || !wifi.hardwareEnabled
    // Four rungs, so one bar is a quarter of the scale. Zero bars is the
    // radio on with no link; a slashed icon is the radio off.
    readonly property int wifiLevel: {
        if (!wifi.connectedNetwork) return 0;
        const s = wifi.connectedNetwork.signalStrength;
        return s >= 0.75 ? 4 : s >= 0.5 ? 3 : s >= 0.25 ? 2 : 1;
    }
    // On with no network: the dim bars and a "!" in the warning tone.
    readonly property bool wifiDown: wifiPresent && !wifiRadioOff && wifiLevel === 0

    readonly property bool volPresent: sound.available
    // Speaker waves: 0 at zero or muted (muted adds the slash), then one
    // wave per third of the scale.
    readonly property int volLevel: sound.volumePercent
    readonly property int volWaves: sound.muted || volLevel <= 0 ? 0 : volLevel <= 33 ? 1 : volLevel <= 66 ? 2 : 3
    readonly property string volIcon: "speaker-" + volWaves
    // Sun rays: one lit ray per eighth of the scale, at least one.
    readonly property int briLevel: Math.max(0, Math.min(100, brightness.shownLevel))
    readonly property int briRays: Math.max(1, Math.min(8, Math.ceil(briLevel / 12.5)))
    readonly property string briIcon: "brightness-" + briRays

    readonly property var ociRows: oci.rows.map(function (row) { return OciModel.rowRule(row); })
    // The worst profile: by tone (danger, warning, normal), then by use.
    readonly property var ociWorst: {
        const rank = {danger: 2, warning: 1};
        let worst = null;
        for (const r of ociRows) {
            const a = rank[r.tone] || 0, b = worst ? rank[worst.tone] || 0 : -1;
            if (a > b || (a === b && (parseFloat(r.value) || 0) > (parseFloat(worst.value) || 0))) worst = r;
        }
        return oci.state === "ready" ? worst : null;
    }
    // The cloud's meter: the worst profile's share of its allowance.
    readonly property real ociFraction: ociWorst ? Math.max(0, Math.min(1, (parseFloat(ociWorst.value) || 0) / 100)) : 0
    readonly property bool ociAlarm: ociWorst !== null && (ociWorst.tone === "warning" || ociWorst.tone === "danger")

    readonly property string ntfNarrow: NotificationModel.barText(notifications.view,
        notifications.status, notifications.count, false).replace(/^NTF ?/, "")
    readonly property string ntfWide: NotificationModel.barText(notifications.view,
        notifications.status, notifications.count, true).replace(/^Notifications ?/, "")
    readonly property string ntfNumber: (/^\d+\+?/.exec(ntfNarrow) || [""])[0]
    // What the wide text adds after the count: ", local only",
    // ", sync error", or "offline".
    readonly property string ntfSuffix: ntfWide.replace(/^\d+\+?/, "")
    readonly property string ntfTone: NotificationModel.barTone(notifications.view,
        notifications.status, notifications.items)
    // The count comes onto the bar only while it warns: an urgent
    // notification (danger) or a sync failure (warning).
    readonly property bool ntfAlarm: ntfTone === "danger" || ntfTone === "warning"

    readonly property var batteryRule: BatteryRule.rule(battery.percent, battery.charging,
        battery.full, battery.onBattery)
    readonly property bool batteryAlarm: batteryRule.tone === "warning" || batteryRule.tone === "danger"

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
    readonly property string appIcon: AppIcon.themeName(appId, appEntry && appEntry.icon ? appEntry.icon : "")

    readonly property string title: frontWindow ? (frontWindow.title || "") : ""
    // The title already names the app ("Forgerie" in "Forgerie"): the
    // Application menu shows its icon alone, so the name is on the bar once.
    readonly property bool titleNamesApp: !dictation.barVisible && appName !== ""
        && title.toLowerCase().indexOf(appName.toLowerCase()) >= 0

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

    // The Super+O chord's keys (modules/hyprland/hyprland.lua topbar-access).
    readonly property var chordKeys: {
        const k = [["B", "Bluetooth"], ["W", "Wi-Fi"], ["S", "Sound"], ["L", "Brightness"]];
        if (bar.oci.enabled) k.push(["C", "Cloud"]);
        if (bar.storage.enabled) k.push(["D", "Disks"]);
        if (bar.fleetPresent) k.push(["F", "Fleet"]);
        if (bar.builderPresent) k.push(["R", "Builder"]);
        k.push(["N", "Notifications"]);
        k.push(["Esc", "cancel"]);
        return k;
    }
    function chordCapWidth(key) { return Math.max(18, PlatinumMetrics.smallWidth(key) + 8); }
    // The chord row: 10 px, then per key its cap and 6 px, and with names
    // the name and 14 px.
    readonly property real chordNamedW: {
        let w = 10;
        for (const k of chordKeys) w += chordCapWidth(k[0]) + 6 + PlatinumMetrics.width(k[1]) + 14;
        return w;
    }
    readonly property real chordCapsW: {
        let w = 10;
        for (const k of chordKeys) w += chordCapWidth(k[0]) + 6;
        return w;
    }

    //----------------------------------------------------------------
    // The plan
    //----------------------------------------------------------------
    // Raw content widths, as bar-plan.js wants them: an icon alone, a
    // readout's text box alone. The planner adds every pad and every gap
    // (the 6 px between icon and readout included), so none is counted here.
    readonly property real clockTimeW: PlatinumMetrics.widest(["12:" + PlatinumMetrics.digits(2),
        "10:" + PlatinumMetrics.digits(2), PlatinumMetrics.digits(1) + ":" + PlatinumMetrics.digits(2)])
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
    // one. A number's box holds its digits at the widest digit's width.
    readonly property string ociName: ociAlarm ? ociWorst.name + ":" : ""
    readonly property real ociReadoutW: ociAlarm ? PlatinumMetrics.width(ociName) + PlatinumMetrics.digitBox(ociWorst.value) : 0
    readonly property string diskWord: diskCounting ? (storage.issues.length === 1 ? " issue" : " issues")
        : storage.state === "error" ? "!" : storage.state === "stale" ? "stale" : ""
    readonly property real diskCountW: diskCounting ? PlatinumMetrics.digitBox(storage.issues.length) : 0
    readonly property real diskReadoutW: diskCountW + (diskWord !== "" ? PlatinumMetrics.width(diskWord) : 0)
    readonly property real fleetReadoutW: fleetReadout.text !== "" ? PlatinumMetrics.digitBox(fleetReadout.text) : 0
    readonly property real ntfReadoutW: !ntfAlarm ? 0 : (ntfNumber !== "" ? PlatinumMetrics.digitBox(ntfNumber) : 0)
        + (ntfSuffix !== "" ? PlatinumMetrics.width(ntfSuffix) : 0)
    readonly property bool ntfShowsReadout: ntfAlarm && plan.show.ntfCount !== false && ntfReadoutW > 0
    readonly property string batteryText: battery.percent + "%"

    readonly property var metrics: ({
        controls: [
            btPresent ? { id: "bt", iconWidth: 16, readoutWidth: 0 } : null,
            // The "!" of a radio with no network never yields.
            wifiPresent ? { id: "wifi", iconWidth: 16, readoutWidth: wifiDown ? PlatinumMetrics.width("!") : 0 } : null,
            volPresent ? { id: "vol", iconWidth: 16, readoutWidth: 0 } : null,
            brightness.available ? { id: "bri", iconWidth: 16, readoutWidth: 0 } : null,
            oci.enabled ? { id: "oci", iconWidth: 22, readoutWidth: ociReadoutW } : null,
            // When the words yield, the issue count keeps its box.
            storage.enabled ? { id: "disk", iconWidth: 16, readoutWidth: diskReadoutW, compactReadoutWidth: diskCountW } : null,
            // Fleet: a light, and a count only when hosts have problems.
            fleetPresent ? { id: "fleet", iconWidth: 12, readoutWidth: fleetReadoutW, compactReadoutWidth: 0 } : null,
            builderPresent ? { id: "builder", iconWidth: 16, readoutWidth: builderControl.fullWidth, compactReadoutWidth: 0 } : null,
            // Offline keeps a "!" once the words yield.
            { id: "ntf", iconWidth: 16, readoutWidth: ntfReadoutW,
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
        clockWidth: clockTimeW,
        chordWidth: chordVisible ? chordNamedW : 0,
        chordCompactWidth: chordVisible ? chordCapsW : 0,
        batteryWidth: battery.present ? 18 : 0,
        batteryReadoutWidth: battery.present && batteryAlarm ? PlatinumMetrics.digitBox(batteryText) : 0,
        // Keep the Application menu reachable, even with no front app:
        // it is where Show All lives. Only tiny bars move it into ».
        appIconWidth: 16,
        appNameWidth: appId !== "" && !titleNamesApp ? PlatinumMetrics.width(appName) : 0,
        overflowWidth: 16
    })

    readonly property var plan: BarPlan.plan(bar.width, bar.metrics)
    readonly property real pad: plan.pad
    function onBar(id) { return plan.controls.indexOf(id) >= 0; }

    // » takes the worst tone of what moved into it, so a warning in the
    // menu still shows on the bar.
    function toneOf(id) {
        if (id === "oci") return bar.oci.tone;
        if (id === "disk") return bar.storage.tone;
        if (id === "fleet") return bar.fleetReadout.tone;
        if (id === "builder") return builderControl.gateTone;
        if (id === "ntf") return bar.ntfTone;
        if (id === "battery") return bar.batteryRule.tone;
        if (id === "wifi") return bar.wifiDown ? "warning" : "normal";
        if (id === "dictation") return "danger";
        return "normal";
    }
    readonly property string moreTone: {
        let worst = "normal";
        for (const id of plan.overflow) {
            const t = bar.toneOf(id);
            if (t === "danger") return "danger";
            if (t === "warning") worst = "warning";
        }
        return worst;
    }

    //----------------------------------------------------------------
    // Balloon Help and the transient tag (drawn by PlatinumBarHelp)
    //----------------------------------------------------------------
    // The title under the pointer, by name.
    readonly property string hoverId: {
        const titles = [["bt", btControl], ["wifi", wifiControl], ["vol", volControl], ["bri", briControl],
            ["oci", ociControl], ["disk", diskControl], ["fleet", fleetControl], ["builder", builderControl],
            ["ntf", ntfControl], ["battery", batteryControl], ["app", appControl],
            ["clock", clockCentre], ["clock", clockRight]];
        for (const t of titles) if (t[1].visible && t[1].hovered) return t[0];
        return "";
    }
    // The balloon shows after the pointer rests 600 ms on a title, while
    // no menu is open on this screen.
    property string balloonId: ""
    readonly property string balloonText: balloonId !== "" ? bar.balloonFor(balloonId) : ""
    Timer {
        id: balloonTimer
        interval: 600
        onTriggered: bar.balloonId = !bar.menuHere && bar.tagId === "" ? bar.hoverId : ""
    }
    onHoverIdChanged: {
        bar.balloonId = "";
        if (bar.hoverId !== "") balloonTimer.restart(); else balloonTimer.stop();
    }

    // The tag: a volume or brightness change shows its number under the
    // control for 1.5 s. Not while a menu is open here (the menu shows
    // the value), and not for the values the owners load at start.
    // Each value arms 2 s after its owner has one, so a sink or a level
    // file that appears later does not raise a tag either.
    property string tagId: ""
    property bool volArmed: false
    property bool briArmed: false
    Timer { id: volArm; interval: 2000; running: true; onTriggered: bar.volArmed = bar.volPresent }
    Timer { id: briArm; interval: 2000; running: true; onTriggered: bar.briArmed = bar.brightness.available }
    readonly property bool briPresent: brightness.available
    onVolPresentChanged: { bar.volArmed = false; volArm.restart(); }
    onBriPresentChanged: { bar.briArmed = false; briArm.restart(); }
    Timer { id: tagTimer; interval: BarPlan.TAG.hold; onTriggered: bar.tagId = "" }
    function showTag(id) {
        if (!bar.visible || bar.menuHere) return;
        if (id === "vol" ? !(bar.volArmed && bar.volPresent) : !(bar.briArmed && bar.briPresent)) return;
        bar.balloonId = "";
        bar.tagId = id;
        tagTimer.restart();
    }
    onVolLevelChanged: bar.showTag("vol")
    readonly property bool volMuted: sound.muted
    onVolMutedChanged: bar.showTag("vol")
    onBriLevelChanged: bar.showTag("bri")
    onMenuHereChanged: if (bar.menuHere) { bar.balloonId = ""; balloonTimer.stop(); bar.tagId = ""; }

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
    // The mark keeps its full width. Below mark + », its Apple menu moves
    // into » instead of clipping either control. The title and the dictation status are readouts and elide
    // in what the plan leaves after it. Retry and Dismiss are controls:
    // they show at full width or move into the » menu, never shrink.
    // The mountain drops the Apple menu, like every other title: inverted
    // while it is open, and part of the sticky hover between titles.
    PlatinumBarControl {
        id: markControl
        visible: bar.plan.show.mark !== false
        x: bar.plan.edge === undefined ? 6 : bar.plan.edge
        screen: bar.modelData
        menu: "apple"
        // The Find menu hangs from the mountain too: Super+P, F1 and Apple
        // menu ▸ Find… open it, and the mountain shows open. A click on the
        // mountain still opens the Apple menu.
        open: bar.isOpen("apple") || bar.isOpen("find")
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
                // Underlined while Go to Address acts on this window.
                font.underline: bar.isOpen("address")
                color: bar.isOpen("address") ? PlatinumTokens.barText : PlatinumTokens.barTextSecondary
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
    // The clock is the time alone; the full date is in its menu and its
    // Balloon Help. It sits in the middle of the bar. Once the bar is too
    // narrow it leaves the centre for the right group, the Mac OS 8 place.
    component ClockTitle: PlatinumBarControl {
        id: clockTitle
        screen: bar.modelData
        menu: "clock"
        open: bar.isOpen("clock")
        pad: bar.pad
        iconWidth: 0
        iconHeight: 0

        Text {
            width: bar.clockTimeW
            horizontalAlignment: Text.AlignHCenter
            text: bar.clockTime(bar.now)
            color: clockTitle.fg
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumText
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
    }

    ClockTitle {
        id: clockCentre
        visible: !bar.chordVisible && bar.plan.centred && bar.plan.show.clock !== false
        x: PlatinumMetrics.even(bar.width / 2 - width / 2)
    }

    // The Super+O chord: each key as a key cap, then what it opens. It
    // stands where the plan reserved it: in the centre, or, once the
    // clock has left the centre, in the clock's place at the head of the
    // right group (chordSlot), so it never covers a control. When the
    // names do not fit, the key caps stay.
    Row {
        id: chord
        visible: bar.chordVisible && bar.plan.show.chord !== false
        readonly property bool compact: !bar.plan.show.chordNames
        x: bar.plan.chordPlace === "right" ? rightGroup.x + chordSlot.x
            : PlatinumMetrics.even(bar.width / 2 - width / 2)
        height: PlatinumTokens.barHeight - PlatinumTokens.hair
        spacing: 0

        Item { width: 10; height: 1 }

        Repeater {
            model: bar.chordKeys

            Row {
                required property var modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                rightPadding: chord.compact ? 6 : 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: bar.chordCapWidth(modelData[0])
                    height: 18
                    radius: 3
                    color: "transparent"
                    border.width: PlatinumTokens.hair
                    border.color: PlatinumTokens.barText

                    Text {
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
        anchors.rightMargin: bar.plan.edge === undefined ? 6 : bar.plan.edge
        height: PlatinumTokens.barHeight - PlatinumTokens.hair
        spacing: bar.plan.gap
        layoutDirection: Qt.LeftToRight

        // The chord's place once the clock has left the centre.
        Item {
            id: chordSlot
            visible: chord.visible && bar.plan.chordPlace === "right"
            width: bar.plan.chordWidth
            height: parent.height
        }

        ClockTitle {
            id: clockRight
            visible: !bar.chordVisible && !bar.plan.centred && bar.plan.show.clock !== false
        }

        // Bluetooth: the rune alone. Grey while on with nothing connected,
        // struck through while off.
        PlatinumBarControl {
            id: btControl
            visible: bar.btPresent && bar.onBar("bt")
            screen: bar.modelData
            menu: "bt"
            open: bar.isOpen("bt")
            pad: bar.pad
            icon: "bluetooth"
            slashed: !bar.btOn
            tone: PlatinumTokens.barTone(bar.btTone)
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
            tone: PlatinumTokens.barTone(bar.wifiDown ? "warning" : "normal")

            Text {
                visible: bar.wifiDown
                text: "!"
                color: wifiControl.fg
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumText
            }
        }

        // Sound: speaker waves for the level, a slash when muted.
        PlatinumBarControl {
            id: volControl
            visible: bar.volPresent && bar.onBar("vol")
            screen: bar.modelData
            menu: "vol"
            open: bar.isOpen("vol")
            pad: bar.pad
            icon: bar.volIcon
            slashed: bar.sound.muted
        }

        // Brightness: one lit ray per eighth of the scale.
        PlatinumBarControl {
            id: briControl
            visible: bar.brightness.available && bar.onBar("bri")
            screen: bar.modelData
            menu: "bri"
            open: bar.isOpen("bri")
            pad: bar.pad
            icon: bar.briIcon
            onWheel: function (delta) { if (delta !== 0) bar.brightness.step(delta > 0 ? 1 : -1); }
        }

        // OCI egress: the cloud and one meter for the worst profile. While
        // a profile warns, its name and percent come onto the bar.
        PlatinumBarControl {
            id: ociControl
            visible: bar.oci.enabled && bar.onBar("oci")
            screen: bar.modelData
            menu: "oci"
            open: bar.isOpen("oci")
            pad: bar.pad
            icon: "cloud-meter"
            iconWidth: 22
            tone: PlatinumTokens.barTone(bar.oci.tone)

            // The meter's fill, inside the icon's well (x 18-20, y 5.33-12),
            // in whole device pixels: at least two once there is any use.
            iconExtras: Rectangle {
                readonly property real dpr: PlatinumTokens.pixelRatio
                readonly property real inner: 20 / 3
                readonly property int device: bar.ociFraction > 0
                    ? Math.max(2, Math.round(inner * dpr * bar.ociFraction)) : 0
                x: 18
                width: 2
                height: Math.min(inner, device / dpr)
                y: 12 - height
                color: ociControl.fg
            }

            Row {
                visible: bar.ociAlarm && bar.plan.show.ociNumber !== false

                Text {
                    text: bar.ociName
                    color: ociControl.inverted ? ociControl.fg : PlatinumTokens.barText
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumText
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
                PlatinumBarNumber {
                    byDigits: true
                    text: bar.ociWorst ? bar.ociWorst.value : ""
                    tone: ociControl.inverted ? ociControl.fg : PlatinumTokens.barTone(bar.ociWorst ? bar.ociWorst.tone : "normal")
                }
            }
        }

        // Server storage: the disk alone while healthy; "1 issue" (or "!",
        // "stale") in its tone otherwise. The words yield before the count.
        PlatinumBarControl {
            id: diskControl
            visible: bar.storage.enabled && bar.onBar("disk")
            screen: bar.modelData
            menu: "disk"
            open: bar.isOpen("disk")
            pad: bar.pad
            icon: "disk"
            tone: PlatinumTokens.barTone(bar.storage.tone)

            Row {
                visible: bar.diskReadoutW > 0 && (bar.plan.show.diskLabel !== false || bar.diskCounting)

                PlatinumBarNumber {
                    visible: bar.diskCounting
                    byDigits: true
                    horizontalAlignment: Text.AlignRight
                    text: String(bar.storage.issues.length)
                    tone: diskControl.fg
                }
                Text {
                    visible: bar.plan.show.diskLabel !== false && bar.diskWord !== ""
                    text: bar.diskWord
                    color: diskControl.fg
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumText
                    font.letterSpacing: PlatinumTokens.platinumTracking
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
                byDigits: true
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

        // Notifications: the bell, with a dot while any wait. The count
        // comes onto the bar only while it warns (urgent, or sync failed).
        PlatinumBarControl {
            id: ntfControl
            visible: bar.onBar("ntf")
            screen: bar.modelData
            menu: "ntf"
            open: bar.isOpen("ntf")
            pad: bar.pad
            icon: "bell"
            tone: ({ danger: PlatinumTokens.barDanger, warning: PlatinumTokens.barWarning,
                     muted: PlatinumTokens.barTextOff })[bar.ntfTone] || PlatinumTokens.barText

            Row {
                visible: bar.ntfShowsReadout

                // With a suffix the digits sit at the box's right end, next
                // to ", local only".
                PlatinumBarNumber {
                    visible: bar.ntfNumber !== ""
                    byDigits: true
                    horizontalAlignment: Text.AlignRight
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
                visible: bar.plan.show.ntfCount === false && bar.ntfOffline
                text: "!"
                color: ntfControl.fg
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumText
            }

            iconExtras: PlatinumBarBadge {
                visible: bar.notifications.count > 0 && !bar.ntfShowsReadout
                fill: ntfControl.fg
                knock: ntfControl.bg
            }
        }

        PlatinumBarControl {
            id: moreControl
            // Below 16 px » itself uses the available width. Override the
            // normal even-pixel rounding so it cannot extend off screen.
            width: bar.plan.overflowIconWidth === undefined ? implicitWidth : 2 * bar.pad + bar.plan.overflowIconWidth
            iconWidth: bar.plan.overflowIconWidth === undefined ? 16 : bar.plan.overflowIconWidth
            visible: bar.plan.overflow.length > 0
            screen: bar.modelData
            menu: "more"
            open: bar.isOpen("more") || (bar.menuHere && bar.plan.overflow.indexOf(MenuState.current) >= 0)
            pad: bar.pad
            icon: "more"
            tone: PlatinumTokens.barTone(bar.moreTone)
        }

        // The battery: its fill is the level. The percent comes onto the
        // bar while it warns (20% or less on battery). Only tiny bars move
        // it into ».
        PlatinumBarControl {
            id: batteryControl
            visible: bar.battery.present && bar.plan.show.battery !== false
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
                visible: bar.batteryAlarm && bar.plan.show.batteryPct !== false
                byDigits: true
                text: bar.batteryText
                tone: batteryControl.fg
            }
        }

        // The Application menu: the front app's icon, and its name only
        // when the window title does not already say it. It drops the
        // running apps (Hide, Hide Others, Show All, then each app). With
        // no front app it shows the desktop mark alone, so Show All stays
        // one click away.
        PlatinumBarControl {
            id: appControl
            visible: bar.plan.show.app !== false
            screen: bar.modelData
            menu: "app"
            open: bar.isOpen("app")
            pad: bar.pad
            icon: bar.appId !== "" ? "" : "desktop"

            iconExtras: IconImage {
                anchors.fill: parent
                implicitSize: 16
                visible: bar.appId !== ""
                source: bar.appId !== "" && bar.appIcon !== "" ? Quickshell.iconPath(bar.appIcon, AppIcon.fallback(bar.appIcon)) : ""
            }

            Text {
                visible: bar.plan.show.appName !== false && bar.appId !== "" && !bar.titleNamesApp
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
