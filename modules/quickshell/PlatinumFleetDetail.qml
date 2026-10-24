import QtQuick
import "beszel-model.js" as Model

// One host's drill-down, a Finder disclosure under its row: the last hour,
// the failed units, the system and the SMART disks. Every value a narrow
// row gave up is here. Two columns when the list is 520 px or wider.
Item {
    id: root

    required property var hv            // Model.hostView
    property var detail: null           // Beszel.details[name]
    property real now: Date.now()
    property real leftInset: 10
    readonly property bool wide: width >= 520
    readonly property real h: PlatinumTokens.hair

    implicitHeight: PlatinumMetrics.even(content.implicitHeight + 8 + 10 + 2 * h)

    function toneColor(tone) {
        return tone === "danger" ? PlatinumTokens.menuDanger : tone === "warning" ? PlatinumTokens.menuWarning
            : tone === "muted" || tone === "quiet" ? PlatinumTokens.menuTextSecondary : PlatinumTokens.menuText;
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

    readonly property bool loaded: root.detail !== null && root.detail !== undefined && root.detail.state === "ready"
    readonly property string missing: root.detail && root.detail.state !== "ready"
        ? "Beszel did not answer. It tries again every minute." : "Loading…"
    readonly property var metrics: root.loaded ? root.detail.metrics : null

    Rectangle {
        anchors.fill: parent
        color: PlatinumGlanceTokens.listSorted
        Rectangle { width: parent.width; height: root.h; color: PlatinumTokens.bevelDark }
        Rectangle { y: parent.height - root.h; width: parent.width; height: root.h; color: PlatinumTokens.bevelDark }
    }

    component Heading: Text {
        textFormat: Text.PlainText
        color: PlatinumTokens.menuTextSecondary
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
        bottomPadding: 3
    }
    component Small: Text {
        textFormat: Text.PlainText
        color: PlatinumTokens.menuText
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
    }
    component Tiny: Text {
        textFormat: Text.PlainText
        color: PlatinumTokens.menuTextSecondary
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumHint
        font.letterSpacing: PlatinumTokens.platinumTracking
    }

    // One sparkline: its label and current value, the well, its axis.
    component Spark: Item {
        id: spark
        property string label: ""
        property string key: "cpu"
        property real max: 100
        property string tone: "normal"
        property var format: Model.fmtPct
        readonly property var s: Model.series(root.metrics, key)
        width: parent ? parent.width : 0
        implicitHeight: Math.max(labelColumn.implicitHeight, 26 + axis.implicitHeight + 1)

        Column {
            id: labelColumn
            width: 66
            Small { text: spark.label }
            Tiny { text: spark.s.now === null ? "--" : spark.format(spark.s.now) + " now" }
        }
        PlatinumSparkline {
            id: well
            x: labelColumn.width + 6
            width: Math.max(40, spark.width - x)
            height: 26
            values: spark.s.values
            max: spark.max
            tone: spark.tone
        }
        Item {
            id: axis
            x: well.x
            y: well.height + 1
            width: well.width
            implicitHeight: axisLeft.implicitHeight
            Tiny { id: axisLeft; text: "1 h ago" }
            Tiny {
                anchors.right: parent.right
                text: spark.s.values.length ? "max " + spark.format(spark.s.max) : ""
            }
        }
    }

    // A label and its value; the value wraps.
    component Pair: Item {
        id: pair
        property string label: ""
        default property alias value: valueBox.data
        width: parent ? parent.width : 0
        implicitHeight: Math.max(labelText.implicitHeight, valueBox.childrenRect.height)
        Small { id: labelText; width: root.kvLabel; text: pair.label; color: PlatinumTokens.menuTextSecondary }
        Item {
            id: valueBox
            x: root.kvLabel + 10
            width: Math.max(0, pair.width - x)
            height: childrenRect.height
        }
    }
    readonly property real kvLabel: kvMetrics.advanceWidth("Filesystems") + 2
    FontMetrics {
        id: kvMetrics
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
    }

    Component {
        id: sparksBlock
        Column {
            spacing: 4
            Heading { text: "Last hour" }
            Small {
                visible: !root.loaded
                width: parent.width
                wrapMode: Text.Wrap
                color: PlatinumTokens.menuTextSecondary
                text: root.missing
            }
            Spark { visible: root.loaded; label: "CPU"; key: "cpu" }
            Spark { visible: root.loaded; label: "Memory"; key: "mem" }
            Spark { visible: root.loaded; label: "Disk"; key: "disk"; tone: root.hv.disk.fs === "/" ? root.hv.disk.tone : "normal" }
            Spark { visible: root.loaded; label: "Network"; key: "net"; max: 0; format: Model.fmtRate }
        }
    }

    Component {
        id: unitsBlock
        Column {
            spacing: 3
            Heading { text: "Failed units" }
            Small {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.Wrap
                readonly property var units: root.loaded && Array.isArray(root.detail.failed) ? root.detail.failed : null
                color: !root.hv.trusted || (units && units.length === 0) || (!units && !(root.hv.failed.n > 0))
                    ? PlatinumTokens.menuTextSecondary : PlatinumTokens.menuDanger
                text: !root.hv.trusted ? "Unknown while " + root.hv.status
                    : units && units.length > 0 ? ""
                    : root.hv.failed.n > 0 ? root.hv.failed.n + " failed. " + (root.loaded ? "Beszel did not list them." : "Loading names…")
                    : "None of " + (root.hv.failed.total === null ? "--" : root.hv.failed.total) + " units"
            }
            Repeater {
                model: root.hv.trusted && root.loaded && Array.isArray(root.detail.failed) ? root.detail.failed : []
                Item {
                    required property string modelData
                    width: parent.width
                    implicitHeight: unitText.implicitHeight
                    Rectangle {
                        x: 0
                        y: (unitText.font.pixelSize - 6) / 2 + 2
                        width: 6; height: 6; radius: 3
                        color: PlatinumTokens.menuDanger
                    }
                    Small {
                        id: unitText
                        x: 12
                        width: parent.width - 12
                        wrapMode: Text.WrapAnywhere
                        color: PlatinumTokens.menuDanger
                        text: modelData
                    }
                }
            }
        }
    }

    Component {
        id: systemBlock
        Column {
            spacing: 3
            Heading { text: "System" }
            Pair {
                label: "Status"
                Flow {
                    width: parent.width
                    Repeater {
                        model: root.hv.reasons.length ? root.hv.reasons : [{tone: "normal", text: root.hv.status === "up" ? "Up, no problems" : root.hv.status}]
                        Small {
                            required property var modelData
                            required property int index
                            text: modelData.text + (index < root.hv.reasons.length - 1 ? ", " : "")
                            color: root.toneColor(modelData.tone)
                        }
                    }
                }
            }
            Pair { label: "Uptime"; Small { width: parent.width; wrapMode: Text.Wrap; text: root.hv.uptime || "--"; color: root.hv.trusted ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff } }
            Pair {
                label: "Seen"
                visible: !root.hv.trusted
                Small { width: parent.width; wrapMode: Text.Wrap; text: root.clock(root.hv.seen) + ", " + Model.ago(root.now - root.hv.seen) }
            }
            Pair {
                label: "Temp"
                Small {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.hv.temp.noSensor ? "No sensor (VM)" : Model.fmtTemp(root.hv.temp.c, true)
                    color: !root.hv.trusted ? PlatinumTokens.menuTextOff : root.toneColor(root.hv.temp.tone)
                }
            }
            Pair {
                label: "CPU now"
                Small { text: Model.fmtPct(root.hv.cpu.pct) + ", memory " + Model.fmtPct(root.hv.mem.pct); color: root.hv.trusted ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff }
            }
            Pair {
                label: "Filesystems"
                Flow {
                    width: parent.width
                    Repeater {
                        model: root.hv.fss
                        Small {
                            required property var modelData
                            required property int index
                            text: modelData.name + " " + Model.fmtPct(modelData.pct) + (index < root.hv.fss.length - 1 ? ", " : "")
                            color: !root.hv.trusted ? PlatinumTokens.menuTextOff
                                : root.toneColor(modelData.pct >= 95 ? "danger" : modelData.pct >= 85 ? "warning" : "normal")
                        }
                    }
                }
            }
            Pair {
                label: "Load"
                Small {
                    width: parent.width
                    wrapMode: Text.Wrap
                    readonly property var load: Array.isArray(root.hv.host.loadAverage) ? root.hv.host.loadAverage : []
                    text: (load.length ? load.map(function (x) { return Number(x).toFixed(2); }).join(" ") : "--")
                        + (root.hv.host.cores ? " on " + root.hv.host.cores + " cores" : "")
                }
            }
            Pair { label: "Processor"; Small { width: parent.width; wrapMode: Text.Wrap; text: Model.cleanCpu(root.hv.host.cpuModel) } }
            Pair { label: "Kernel"; Small { width: parent.width; wrapMode: Text.WrapAnywhere; text: root.hv.host.kernel || "--" } }
            Pair {
                label: "Agent"
                Small {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: (root.hv.host.agentVersion || "--") + (root.hv.host.connectionType ? ", " + root.hv.host.connectionType : "")
                }
            }
        }
    }

    Component {
        id: disksBlock
        Column {
            spacing: 3
            Heading { text: "Disks" }
            Small {
                visible: !root.loaded || !Array.isArray(root.detail.smart) || root.detail.smart.length === 0
                width: parent.width
                wrapMode: Text.Wrap
                color: PlatinumTokens.menuTextSecondary
                text: !root.loaded ? root.missing : "No SMART data"
            }
            Repeater {
                model: root.loaded && Array.isArray(root.detail.smart) ? root.detail.smart : []
                Column {
                    required property var modelData
                    width: parent.width
                    readonly property string verdict: modelData.smartState === "PASSED" ? "Passed"
                        : modelData.smartState === "FAILED" || modelData.healthy === false && modelData.smartState !== "UNKNOWN" ? "Failed" : "No data"
                    Item {
                        width: parent.width
                        implicitHeight: diskName.implicitHeight
                        Small { id: diskName; width: Math.min(implicitWidth, parent.width * 0.3); elide: Text.ElideRight; text: String(modelData.name || "").replace(/^\/dev\//, "") }
                        Small {
                            x: Math.max(diskName.width + 8, parent.width * 0.3)
                            text: parent.parent.verdict
                            color: parent.parent.verdict === "Failed" ? PlatinumTokens.menuDanger
                                : parent.parent.verdict === "Passed" ? PlatinumTokens.menuText : PlatinumTokens.menuTextSecondary
                        }
                        Small {
                            anchors.right: parent.right
                            text: (typeof modelData.temperatureC === "number" && modelData.temperatureC > 0 ? Math.round(modelData.temperatureC) + "°   " : "")
                                + (typeof modelData.powerOnHours === "number" && modelData.powerOnHours > 0 ? modelData.powerOnHours.toLocaleString(Qt.locale("en_US"), "f", 0) + " h" : "")
                        }
                    }
                    Tiny {
                        x: Math.max(diskName.width + 8, parent.width * 0.3)
                        width: parent.width - x
                        wrapMode: Text.WrapAnywhere
                        text: [modelData.model || "", root.capacity(modelData.capacityGb)].filter(function (s) { return s !== ""; }).join(", ")
                    }
                }
            }
        }
    }

    Column {
        id: content
        x: root.wide ? root.leftInset : 10
        y: 8 + root.h
        width: parent.width - x - 10
        spacing: 10

        Small {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.2
            color: root.hv.status === "down" ? root.toneColor(root.hv.tone) : PlatinumTokens.menuTextSecondary
            text: root.hv.status === "down"
                ? "Down. Last seen at " + root.clock(root.hv.seen) + ", " + Model.ago(root.now - root.hv.seen)
                    + ". The values below are from then and may be wrong."
                    + (["myoko", "hiyori"].indexOf(root.hv.name) >= 0 ? " This is a desktop, so down is normal when it sleeps or is unplugged." : "")
                : root.hv.status === "paused" ? "Monitoring is paused in Beszel. The values below are from before the pause."
                : root.hv.status === "pending" ? "Beszel has not had a report from " + root.hv.name + " yet." : ""
        }

        Row {
            visible: root.wide
            width: parent.width
            spacing: 18
            readonly property real leftW: Math.floor((width - spacing) * 1.15 / 2.15)
            Column {
                width: parent.leftW
                spacing: 12
                Loader { width: parent.width; active: root.wide; sourceComponent: sparksBlock }
                Loader { width: parent.width; active: root.wide; sourceComponent: unitsBlock }
            }
            Column {
                width: parent.width - parent.leftW - parent.spacing
                spacing: 12
                Loader { width: parent.width; active: root.wide; sourceComponent: systemBlock }
                Loader { width: parent.width; active: root.wide; sourceComponent: disksBlock }
            }
        }

        Column {
            visible: !root.wide
            width: parent.width
            spacing: 12
            Loader { width: parent.width; active: !root.wide; sourceComponent: sparksBlock }
            Loader { width: parent.width; active: !root.wide; sourceComponent: unitsBlock }
            Loader { width: parent.width; active: !root.wide; sourceComponent: systemBlock }
            Loader { width: parent.width; active: !root.wide; sourceComponent: disksBlock }
        }
    }
}
