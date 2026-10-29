pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import QtQuick
import "beszel-model.js" as Model

// One host's drill-down in the Windows 98 form: a Properties sheet (the
// approved mock pass 2, Simon's accepted default 2). Platinum's four
// sections are four tabs: General (System), Performance (the last hour, as
// System Monitor charts), Services (the failed units) and Disks (the
// filesystems as drive pies, then SMART). One size for every tab, as Win98's
// sheets had; a tab whose content is taller scrolls inside the sheet. The
// tabs stay in one row and scroll with an up-down control when the sheet is
// narrow. Close (or Esc in the host) closes it; Ctrl+Tab changes the tab.
//
// The host places it (themes/win98/fleet-plan.js sheetRect): beside the
// Fleet window, or over it when there is no room.
Win98Window {
    id: root

    required property var panel        // panels/Beszel.qml
    required property var prefs        // Win98FleetGlance: tab
    required property var hv           // beszel-model.js hostView
    property real now: panel.now

    readonly property var detail: panel.details[hv.name] || null
    readonly property bool loaded: detail !== null && detail.state === "ready"
    readonly property string missing: detail && detail.state !== "ready"
        ? "Beszel did not answer. It tries again every minute." : "Loading..."
    readonly property var tabNames: ["&General", "&Performance", "&Services", "&Disks"]
    readonly property int tab: Math.max(0, Math.min(3, prefs.tab))

    title: hv.name + " Properties"
    iconItem: Component { Win98HostIcon { hostStatus: root.hv.status; tone: root.hv.tone } }
    margins: false
    onCloseClicked: root.panel.expanded = ""

    function units(n) { return n * root.u; }
    function toneInk(tone) {
        return tone === "danger" ? Kit.Win98Tokens.danger : tone === "warning" ? Kit.Win98Tokens.warning
            : tone === "muted" ? Kit.Win98Tokens.gray : Kit.Win98Tokens.text;
    }
    function clock(ms) {
        if (!isFinite(ms)) return "--";
        const d = new Date(ms);
        return (d.getHours() % 12 || 12) + Qt.formatTime(d, ":mm");
    }
    function capacity(gb) {
        if (typeof gb !== "number" || !isFinite(gb)) return "";
        return gb >= 1000 ? Math.round(gb / 1000) + " TB" : Math.round(gb) + " GB";
    }
    function select(i) { root.prefs.tab = (i + 4) % 4; sheet.contentY = 0; }

    // Esc closes the sheet (the host's window stays).
    signal escapePressed
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) { root.panel.expanded = ""; root.escapePressed(); event.accepted = true; }
        else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) { root.select(root.tab + 1); event.accepted = true; }
        else if (event.key === Qt.Key_Backtab && (event.modifiers & Qt.ControlModifier)) { root.select(root.tab - 1); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { sheet.contentY = Math.min(Math.max(0, sheet.contentHeight - sheet.height), sheet.contentY + root.units(16)); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { sheet.contentY = Math.max(0, sheet.contentY - root.units(16)); event.accepted = true; }
        else if ((event.modifiers & Qt.AltModifier) && [Qt.Key_G, Qt.Key_P, Qt.Key_S, Qt.Key_D].indexOf(event.key) >= 0) {
            root.select([Qt.Key_G, Qt.Key_P, Qt.Key_S, Qt.Key_D].indexOf(event.key)); event.accepted = true;
        }
    }

    // The body: the tabs and their sheet, then Close.
    Item {
        id: body
        readonly property real innerW: root.width - 2 * root.frame
        readonly property real innerH: root.height - root.captionBottom - root.frame
        width: innerW
        height: innerH
        implicitHeight: innerH

        Win98Tabs {
            id: tabs
            objectName: "propsTabs"
            x: root.units(4)
            y: root.units(6)
            width: body.innerW - root.units(8)
            height: body.innerH - root.units(6 + 6 + 23 + 4)
            singleRow: true
            padUnits: 6
            tabs: root.tabNames
            currentIndex: root.tab
            showFocus: root.Window.activeFocusItem === tabs
            onSelected: function (i) { root.select(i); }

            Item {
                id: page
                width: tabs.width - root.units(12)
                height: tabs.height - tabs.strip + root.units(2) - root.units(12)
                clip: true
                Flickable {
                    id: sheet
                    width: page.width - (vbar.visible ? root.units(18) : 0)
                    height: page.height
                    contentHeight: Math.ceil(content.contentH / root.u) * root.u
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds
                    WheelHandler {
                        enabled: sheet.contentHeight > sheet.height
                        onWheel: event => sheet.contentY = Math.max(0, Math.min(sheet.contentHeight - sheet.height,
                            sheet.contentY - Math.sign(event.angleDelta.y) * root.units(32)))
                    }
                    Loader {
                        id: content
                        width: sheet.width
                        readonly property real contentH: item ? (item as Item).implicitHeight : 0
                        sourceComponent: [generalTab, performanceTab, servicesTab, disksTab][root.tab]
                    }
                }
                Win98ScrollBar {
                    id: vbar
                    visible: sheet.contentHeight > sheet.height + 0.5
                    x: page.width - width
                    height: page.height
                    flickable: sheet
                    step: root.units(16)
                }
            }
        }

        Win98Button {
            id: closeButton
            objectName: "propsClose"
            x: body.innerW - root.units(4) - width
            y: body.innerH - root.units(4) - height
            text: "Close"
            isDefault: true
            widthUnits: 75
            onClicked: root.panel.expanded = ""
        }
    }

    // ---------------------------------------------------------- pieces
    component Label: Win98Text {
        accessMarks: false
        wrap: true
        width: parent ? parent.width : 0
    }
    // The note a host that is not up shows over every tab.
    component DownNote: Item {
        id: note
        readonly property string text: root.hv.status === "down"
            ? "Down. Last seen at " + root.clock(root.hv.seen) + ", " + Model.ago(root.now - root.hv.seen)
                + ". The values below are from then and may be wrong."
                + (Model.DESKTOPS.indexOf(root.hv.name) >= 0 ? " This is a desktop, so down is normal when it sleeps or is unplugged." : "")
            : root.hv.status === "paused" ? "Monitoring is paused in Beszel. The values below are from before the pause."
            : root.hv.status !== "up" ? "Beszel has not had a report from " + root.hv.name + " yet." : ""
        readonly property bool danger: root.hv.status === "down" && root.hv.tone === "danger"
        visible: text !== ""
        width: parent ? parent.width : 0
        implicitHeight: visible ? noteText.implicitHeight + root.units(8) : 0
        height: implicitHeight
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: root.u
            border.color: note.danger ? Kit.Win98Tokens.danger : Kit.Win98Tokens.gray
        }
        Win98HostIcon {
            x: root.units(6); y: root.units(4)
            hostStatus: root.hv.status === "up" ? "pending" : root.hv.status
            tone: root.hv.tone
        }
        Win98Text {
            id: noteText
            x: root.units(6 + 16 + 6)
            y: root.units(4)
            width: note.width - x - root.units(6)
            wrap: true
            accessMarks: false
            text: note.text
            color: note.danger ? Kit.Win98Tokens.danger : Kit.Win98Tokens.text
        }
    }
    component Etch: Item {
        width: parent ? parent.width : 0
        height: root.units(2)
        Rectangle { width: parent.width; height: root.u; color: Kit.Win98Tokens.sh }
        Rectangle { y: root.u; width: parent.width; height: root.u; color: Kit.Win98Tokens.hi }
    }

    // General: the host, its status and its system facts.
    Component {
        id: generalTab
        Column {
            id: general
            spacing: root.units(6)
            readonly property bool narrow: width < root.units(200)
            readonly property real keyW: Kit.Win98Tokens.ceilU(Kit.Win98Tokens.widest(["Filesystems:"], false, root.u), root.u)
            readonly property var host: root.hv.host
            readonly property var pairs: {
                const v = root.hv, h = v.host;
                const fss = v.fss.map(function (f) { return f.name + " " + Model.fmtPct(f.pct); }).join(", ");
                const load = Array.isArray(h.loadAverage) ? h.loadAverage.map(function (x) { return Number(x).toFixed(2); }).join(" ") : "";
                return [
                    ["Status", v.reasons.length ? v.reasons.map(function (r) { return r.text; }).join(", ") : (v.status === "up" ? "Up, no problems" : v.status),
                        v.reasons.length ? v.reasons[0].tone : "normal"],
                    ["Uptime", v.uptime || "--", ""],
                    ["Temp", v.temp.noSensor ? "No sensor (VM)" : Model.fmtTemp(v.temp.c, true), v.temp.tone],
                    ["Filesystems", fss, v.disk.tone],
                    ["Load", (load || "--") + (h.cores ? " on " + h.cores + " cores" : ""), ""],
                    ["CPU", Model.cleanCpu(h.cpuModel), ""],
                    ["Kernel", h.kernel || "--", ""],
                    ["Agent", (h.agentVersion || "--") + (h.connectionType ? ", " + h.connectionType : ""), ""]
                ];
            }
            Row {
                spacing: root.units(8)
                Win98HostIcon { size: 32; hostStatus: root.hv.status; tone: root.hv.tone }
                Column {
                    Win98Text { text: root.hv.name; bold: true; accessMarks: false; color: root.toneInk(root.hv.tone) }
                    Win98Text {
                        text: root.hv.status.charAt(0).toUpperCase() + root.hv.status.slice(1)
                        accessMarks: false
                        color: Kit.Win98Tokens.gray
                    }
                }
            }
            Etch {}
            DownNote {}
            Repeater {
                model: general.pairs
                Item {
                    id: pair
                    required property var modelData
                    readonly property bool untrusted: !root.hv.trusted && pair.modelData[0] !== "Status"
                    width: general.width
                    implicitHeight: general.narrow ? key.implicitHeight + value.implicitHeight : Math.max(key.implicitHeight, value.implicitHeight)
                    height: implicitHeight
                    Win98Text {
                        id: key
                        text: pair.modelData[0] + ":"
                        accessMarks: false
                        color: general.narrow ? Kit.Win98Tokens.gray : Kit.Win98Tokens.text
                    }
                    Win98Text {
                        id: value
                        x: general.narrow ? 0 : general.keyW + root.units(8)
                        y: general.narrow ? key.implicitHeight : 0
                        width: general.width - x
                        wrap: true
                        accessMarks: false
                        text: pair.modelData[1]
                        color: pair.untrusted ? Kit.Win98Tokens.gray : pair.modelData[2] ? root.toneInk(pair.modelData[2]) : Kit.Win98Tokens.text
                    }
                }
            }
        }
    }

    // Performance: CPU, memory, disk and network over the last hour.
    Component {
        id: performanceTab
        Column {
            id: perf
            spacing: root.units(3)
            readonly property real chartH: Math.max(18, Math.min(40, Math.floor((sheet.height / root.u - (perfNote.visible ? 60 : 0) - 4 * 34) / 4)))
            DownNote { id: perfNote }
            Label { visible: !root.loaded; text: root.missing; color: Kit.Win98Tokens.gray }
            Repeater {
                model: root.loaded ? [
                    { label: "CPU", key: "cpu", max: 100, color: Kit.Win98Tokens.chartCpu, tone: "normal" },
                    { label: "Memory", key: "mem", max: 100, color: Kit.Win98Tokens.chartMem, tone: "normal" },
                    { label: "Disk", key: "disk", max: 100, color: Kit.Win98Tokens.chartDisk, tone: root.hv.disk.fs === "/" ? root.hv.disk.tone : "normal" },
                    { label: "Network", key: "net", max: 0, color: Kit.Win98Tokens.chartNet, tone: "normal" }
                ] : []
                Item {
                    id: spark
                    required property var modelData
                    readonly property var s: Model.series(root.detail.metrics, modelData.key)
                    readonly property var fmt: modelData.key === "net" ? Model.fmtRate : Model.fmtPct
                    width: perf.width
                    implicitHeight: Math.max(labels.implicitHeight, chart.height + root.units(13))
                    height: implicitHeight
                    Column {
                        id: labels
                        width: root.units(58)
                        Win98Text { text: spark.modelData.label; bold: true; accessMarks: false }
                        Win98Text {
                            width: labels.width
                            wrap: true
                            accessMarks: false
                            color: Kit.Win98Tokens.gray
                            text: (spark.s.now === null ? "--" : spark.fmt(spark.s.now)) + " now"
                        }
                    }
                    Win98SysmonChart {
                        id: chart
                        x: root.units(62)
                        width: Math.max(root.units(40), spark.width - x)
                        height: root.units(perf.chartH)
                        values: spark.s.values
                        max: spark.modelData.max
                        stale: !root.hv.trusted
                        lineColor: spark.modelData.tone === "danger" ? Kit.Win98Tokens.meterDanger
                            : spark.modelData.tone === "warning" ? Kit.Win98Tokens.meterWarn : spark.modelData.color
                    }
                    Win98Text {
                        x: chart.x
                        y: chart.height
                        text: "1 h ago"
                        accessMarks: false
                        color: Kit.Win98Tokens.gray
                    }
                    Win98Text {
                        x: chart.x + chart.width - width
                        y: chart.height
                        visible: spark.s.values.length > 0
                        text: "max " + spark.fmt(spark.s.max)
                        accessMarks: false
                        color: Kit.Win98Tokens.gray
                    }
                }
            }
        }
    }

    // Services: the failed units, in a list whose rows show their full
    // name below when clicked.
    Component {
        id: servicesTab
        Column {
            id: services
            spacing: root.units(6)
            readonly property var units: root.hv.trusted && root.loaded && Array.isArray(root.detail.failed) ? root.detail.failed : []
            property int chosen: -1
            DownNote {}
            Win98Text {
                width: services.width
                wrap: true
                accessMarks: false
                color: root.hv.trusted && root.hv.failed.n > 0 ? Kit.Win98Tokens.danger : Kit.Win98Tokens.text
                text: !root.hv.trusted || !(root.hv.failed.n > 0) ? "Failed units"
                    : root.hv.failed.n + (root.hv.failed.n === 1 ? " failed unit" : " failed units") + " of " + (root.hv.failed.total === null ? "--" : root.hv.failed.total)
            }
            Win98Bevel {
                id: unitWell
                width: services.width
                height: root.units(Math.max(60, 17 + 4 + Math.max(1, services.units.length) * 16 + 4))
                variant: "field"
                color: Kit.Win98Tokens.win
                Win98HeaderView {
                    visible: services.units.length > 0
                    x: root.units(2); y: root.units(2)
                    width: unitWell.width - root.units(4)
                    height: root.units(17)
                    columns: [{ id: "unit", label: "Failed unit", width: unitWell.width - root.units(4) }]
                }
                Column {
                    x: root.units(2)
                    y: root.units(services.units.length ? 19 : 2)
                    width: unitWell.width - root.units(4)
                    Repeater {
                        model: services.units
                        Rectangle {
                            id: unitRow
                            required property string modelData
                            required property int index
                            readonly property bool on: services.chosen === index
                            objectName: "unit-" + index
                            width: parent.width
                            height: root.units(16)
                            color: on ? Kit.Win98Tokens.selection : "transparent"
                            Win98Icon { x: root.units(3); y: root.units(2); name: "bad" }
                            Win98Text {
                                x: root.units(3 + 12 + 3)
                                y: root.units(2)
                                width: Math.min(implicitWidth, unitRow.width - x - root.units(2))
                                text: unitRow.modelData
                                accessMarks: false
                                color: unitRow.on ? Kit.Win98Tokens.selectionText : Kit.Win98Tokens.danger
                            }
                            MouseArea { anchors.fill: parent; onClicked: services.chosen = unitRow.index }
                        }
                    }
                    Win98Text {
                        visible: services.units.length === 0
                        x: root.units(6)
                        y: root.units(6)
                        width: parent.width - root.units(12)
                        wrap: true
                        accessMarks: false
                        color: root.hv.trusted && root.hv.failed.n > 0 ? Kit.Win98Tokens.danger : Kit.Win98Tokens.gray
                        text: !root.hv.trusted ? "Unknown while " + root.hv.status
                            : root.hv.failed.n > 0 ? root.hv.failed.n + " failed. " + (root.loaded ? "Beszel did not list them." : "Loading names...")
                            : "None of " + (root.hv.failed.total === null ? "--" : root.hv.failed.total) + " units"
                    }
                }
            }
            Win98Text {
                width: services.width
                wrap: true
                accessMarks: false
                color: services.chosen >= 0 ? Kit.Win98Tokens.text : Kit.Win98Tokens.gray
                text: services.chosen >= 0 && services.units[services.chosen] ? services.units[services.chosen]
                    : services.units.length ? "Click a unit to read its full name." : "From list_services, state Failed."
            }
        }
    }

    // Disks: each filesystem as a drive pie, then the SMART disks.
    Component {
        id: disksTab
        Column {
            id: disks
            spacing: root.units(6)
            readonly property var smart: root.loaded && Array.isArray(root.detail.smart) ? root.detail.smart : []
            DownNote {}
            Flow {
                width: disks.width
                spacing: root.units(10)
                Repeater {
                    model: root.hv.fss
                    Row {
                        id: pie
                        required property var modelData
                        spacing: root.units(6)
                        Win98PieChart { percent: pie.modelData.pct === null ? 0 : pie.modelData.pct; stale: !root.hv.trusted || pie.modelData.pct === null }
                        Column {
                            y: root.units(2)
                            Win98Text { text: pie.modelData.name === "/" ? "Root (/)" : pie.modelData.name; bold: true; accessMarks: false }
                            Win98Text {
                                text: Model.fmtPct(pie.modelData.pct) + " used"
                                accessMarks: false
                                color: !root.hv.trusted ? Kit.Win98Tokens.gray : root.toneInk(Model.fsTone(pie.modelData.pct))
                            }
                        }
                    }
                }
            }
            Row {
                spacing: root.units(8)
                Repeater {
                    model: [["Used", Kit.Win98Tokens.pieUsed], ["Free", Kit.Win98Tokens.pieFree]]
                    Row {
                        id: swatch
                        required property var modelData
                        spacing: root.units(4)
                        Rectangle {
                            y: root.units(2)
                            width: root.units(9); height: root.units(9)
                            color: swatch.modelData[1]
                            border.width: root.u
                            border.color: Kit.Win98Tokens.dk
                        }
                        Win98Text { text: swatch.modelData[0]; accessMarks: false }
                    }
                }
            }
            Etch {}
            Win98Text { text: "SMART"; accessMarks: false }
            Win98Bevel {
                id: smartWell
                width: disks.width
                height: root.units(4 + (disks.smart.length ? 17 + disks.smart.length * 30 : 30))
                variant: "field"
                color: Kit.Win98Tokens.win
                readonly property real cw: width - root.units(4)
                Win98HeaderView {
                    visible: disks.smart.length > 0
                    x: root.units(2); y: root.units(2)
                    width: smartWell.cw
                    height: root.units(17)
                    columns: [
                        { id: "dev", label: "Device", width: root.units(62) },
                        { id: "smart", label: "SMART", width: root.units(52) },
                        { id: "temp", label: "Temp", width: Math.max(root.units(30), smartWell.cw - root.units(62 + 52 + 66)), alignRight: true },
                        { id: "hours", label: "Hours", width: root.units(66), alignRight: true }
                    ]
                }
                Win98Text {
                    visible: disks.smart.length === 0
                    x: root.units(6); y: root.units(8)
                    width: smartWell.cw - root.units(8)
                    wrap: true
                    accessMarks: false
                    color: Kit.Win98Tokens.gray
                    text: !root.loaded ? root.missing : "No SMART data"
                }
                Column {
                    x: root.units(2)
                    y: root.units(19)
                    width: smartWell.cw
                    Repeater {
                        model: disks.smart
                        Item {
                            id: drive
                            required property var modelData
                            readonly property string verdict: modelData.smartState === "PASSED" ? "Passed"
                                : modelData.smartState === "FAILED" || modelData.healthy === false && modelData.smartState !== "UNKNOWN" ? "Failed" : "No data"
                            width: parent.width
                            height: root.units(30)
                            Win98Icon { visible: drive.verdict === "Failed"; x: root.units(3); y: root.units(2); name: "bad" }
                            Win98Text {
                                x: root.units(drive.verdict === "Failed" ? 17 : 3)
                                y: root.units(1)
                                width: Math.min(implicitWidth, root.units(62) - x)
                                text: String(drive.modelData.name || "").replace(/^\/dev\//, "")
                                accessMarks: false
                                color: Kit.Win98Tokens.winText
                            }
                            Win98Text {
                                x: root.units(62 + 3)
                                y: root.units(1)
                                text: drive.verdict
                                accessMarks: false
                                color: drive.verdict === "Failed" ? Kit.Win98Tokens.danger : drive.verdict === "Passed" ? Kit.Win98Tokens.winText : Kit.Win98Tokens.gray
                            }
                            Win98Text {
                                x: drive.width - root.units(66 + 4) - width
                                y: root.units(1)
                                text: typeof drive.modelData.temperatureC === "number" && drive.modelData.temperatureC > 0 ? Math.round(drive.modelData.temperatureC) + "°" : "--"
                                accessMarks: false
                                color: Kit.Win98Tokens.winText
                            }
                            Win98Text {
                                x: drive.width - root.units(4) - width
                                y: root.units(1)
                                text: typeof drive.modelData.powerOnHours === "number" && drive.modelData.powerOnHours > 0
                                    ? drive.modelData.powerOnHours.toLocaleString(Qt.locale("en_US"), "f", 0) + " h" : "--"
                                accessMarks: false
                                color: Kit.Win98Tokens.winText
                            }
                            Win98Text {
                                x: root.units(62 + 3)
                                y: root.units(15)
                                width: Math.min(implicitWidth, drive.width - x - root.units(4))
                                text: [drive.modelData.model || "", root.capacity(drive.modelData.capacityGb)].filter(function (s) { return s !== ""; }).join(", ")
                                accessMarks: false
                                color: Kit.Win98Tokens.gray
                            }
                        }
                    }
                }
            }
        }
    }
}
