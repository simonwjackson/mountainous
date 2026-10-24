import QtQuick
import "beszel-model.js" as Model
import "fleet-plan.js" as Plan

// One host in the Fleet list: a disclosure triangle, the status light, the
// name, then the columns the plan keeps. A host that is not up shows its
// last values greyed, and the values set no tone.
Item {
    id: row

    required property var hv
    required property var plan
    required property var panel
    property real now: Date.now()
    property bool focusRing: false
    signal clicked

    readonly property real h: PlatinumTokens.hair
    readonly property bool selected: hv !== null && panel.selected === hv.name
    readonly property bool open: hv !== null && panel.expanded === hv.name
    readonly property var level: Plan.LEVELS[plan.level]
    readonly property bool stale: hv !== null && !hv.trusted

    height: plan.rowH

    function color(tone) {
        if (row.selected) return PlatinumTokens.highlightText;
        return tone === "danger" ? PlatinumTokens.menuDanger : tone === "warning" ? PlatinumTokens.menuWarning
            : tone === "muted" || tone === "quiet" ? PlatinumTokens.menuTextSecondary
            : tone === "stale" ? PlatinumTokens.menuTextOff : PlatinumTokens.menuText;
    }
    function valueTone(tone) { return row.stale ? "stale" : tone; }

    Rectangle {
        anchors.fill: parent
        color: row.selected ? PlatinumTokens.highlight : "transparent"
    }
    // The sorted column keeps its tint under the row.
    Rectangle {
        visible: !row.selected && sortedCell !== null
        readonly property var sortedCell: row.panel.sort === "name" ? nameCell
            : cells.itemAt(row.plan.cols.indexOf(row.panel.sort)) || null
        x: sortedCell ? sortedCell.x : 0
        width: sortedCell ? sortedCell.width : 0
        height: parent.height
        color: PlatinumGlanceTokens.listSorted
    }
    // Keyboard focus: an inner hair around the selected row.
    Rectangle {
        visible: row.selected && row.focusRing
        anchors.fill: parent
        color: "transparent"
        border.width: row.h
        border.color: PlatinumTokens.highlightText
    }

    MouseArea {
        anchors.fill: parent
        onClicked: row.clicked()
    }

    FontMetrics {
        id: fsMetrics
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumHint
        font.letterSpacing: PlatinumTokens.platinumTracking
    }

    TextMetrics {
        id: valueBox
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
        text: "100%"
    }

    component Value: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
    }

    Row {
        height: parent.height

        // The Finder disclosure triangle: right, or down when open.
        Item {
            width: Plan.C.TRI
            height: parent.height
            Image {
                anchors.centerIn: parent
                width: 10
                height: 10
                smooth: true
                sourceSize.width: Math.ceil(width * PlatinumTokens.pixelRatio)
                sourceSize.height: Math.ceil(height * PlatinumTokens.pixelRatio)
                readonly property color ink: row.selected ? PlatinumTokens.highlightText : PlatinumTokens.menuText
                source: "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10"><path fill="'
                    + ink + '" d="' + (row.open ? "M1 2.5 L9 2.5 L5 8.5 Z" : "M2.5 1 L8.5 5 L2.5 9 Z") + '"/></svg>')
            }
        }
        Item {
            width: Plan.C.LAMP
            height: parent.height
            PlatinumStatusLight {
                anchors.centerIn: parent
                shape: row.hv ? (row.hv.status === "up" ? "up" : row.hv.status === "down" ? "down"
                    : row.hv.status === "paused" ? "paused" : "pending") : "up"
                tone: row.hv ? row.hv.tone : "muted"
            }
        }
        Item {
            id: nameCell
            width: row.plan.nameW
            height: parent.height
            Text {
                x: row.plan.pad
                width: Math.max(0, parent.width - 2 * row.plan.pad)
                anchors.verticalCenter: parent.verticalCenter
                text: row.hv ? row.hv.name : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: row.color(row.hv ? row.hv.tone : "normal")
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumText
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }

        Repeater {
            id: cells
            model: row.plan.cols
            Item {
                id: cell
                required property string modelData
                width: row.plan.widths[modelData]
                height: row.height
                readonly property real inner: width - 2 * row.plan.pad
                readonly property bool bar: row.level.bar > 0 && (!row.level.barCols || row.level.barCols.indexOf(modelData) >= 0)
                readonly property var hv: row.hv

                // CPU, memory, disk: an optional bar, then the number.
                Row {
                    visible: ["cpu", "mem", "disk"].indexOf(cell.modelData) >= 0 && cell.hv !== null
                    anchors.right: parent.right
                    anchors.rightMargin: row.plan.pad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    readonly property var metric: cell.hv === null ? null
                        : cell.modelData === "cpu" ? cell.hv.cpu : cell.modelData === "mem" ? cell.hv.mem : cell.hv.disk
                    Text {
                        visible: cell.modelData === "disk" && cell.bar && cell.hv !== null && cell.hv.trusted && cell.hv.disk.fs !== "/"
                        anchors.verticalCenter: parent.verticalCenter
                        width: visible ? Math.min(Math.ceil(fsMetrics.advanceWidth(text)), 70) + 4 : 0
                        elide: Text.ElideRight
                        text: cell.hv ? cell.hv.disk.fs : ""
                        textFormat: Text.PlainText
                        color: row.selected ? PlatinumTokens.highlightText : PlatinumTokens.menuTextSecondary
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumHint
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                    PlatinumProgressBar {
                        visible: cell.bar
                        anchors.verticalCenter: parent.verticalCenter
                        width: visible ? row.level.bar : 0
                        value: parent.metric && parent.metric.pct !== null ? parent.metric.pct : NaN
                        tone: cell.modelData === "disk" && parent.metric ? parent.metric.tone : "normal"
                        stale: row.stale
                        selected: row.selected
                    }
                    Item { width: cell.bar ? Plan.C.BAR_GAP : 0; height: 1 }
                    Value {
                        width: cell.bar ? Math.max(implicitWidth, valueBox.advanceWidth) : implicitWidth
                        horizontalAlignment: Text.AlignRight
                        text: parent.metric ? Model.fmtPct(parent.metric.pct) : "--"
                        color: row.color(row.valueTone(cell.modelData === "disk" && parent.metric ? parent.metric.tone : "normal"))
                    }
                }

                // Temp, failed, uptime, notes, the reason: one text.
                Value {
                    visible: ["cpu", "mem", "disk"].indexOf(cell.modelData) < 0 && cell.hv !== null
                    x: row.plan.pad
                    width: Math.max(0, cell.inner)
                    horizontalAlignment: cell.modelData === "why" ? Text.AlignLeft : Text.AlignRight
                    readonly property var topReason: cell.hv && cell.hv.reasons.length ? cell.hv.reasons[0] : null
                    readonly property var noteReason: {
                        if (!cell.hv) return null;
                        if (cell.hv.status !== "up") return topReason;
                        for (const r of cell.hv.reasons) if (/failed|°/.test(r.short)) return r;
                        return null;
                    }
                    readonly property string whyText: {
                        if (!topReason) return "OK";
                        const more = cell.hv.reasons.length > 1 ? " +" + (cell.hv.reasons.length - 1) : "";
                        const variants = [topReason.text + more, topReason.short + more, topReason.short];
                        for (const v of variants) if (whyMetrics.advanceWidth(v) <= cell.inner) return v;
                        return topReason.short;
                    }
                    FontMetrics { id: whyMetrics; font.family: PlatinumTokens.platinumFont; font.pixelSize: PlatinumTokens.platinumSmall; font.letterSpacing: PlatinumTokens.platinumTracking }
                    text: {
                        const v = cell.hv;
                        if (!v) return "";
                        switch (cell.modelData) {
                        case "temp": return Model.fmtTemp(v.temp.c);
                        case "failed": return v.failed.n === null ? "--" : String(v.failed.n);
                        case "up":
                            if (v.status === "paused" || v.status === "pending") return v.status;
                            if (v.status === "down") return row.level.up === "long"
                                ? "seen " + Model.agoShort(row.now - v.seen) + " ago" : Model.agoShort(row.now - v.seen);
                            return Model.fmtUptime(v.uptime, row.level.up);
                        case "notes": return noteReason ? noteReason.short : "";
                        case "why": return whyText;
                        }
                        return "";
                    }
                    color: {
                        const v = cell.hv;
                        if (!v) return PlatinumTokens.menuText;
                        switch (cell.modelData) {
                        case "temp": return row.color(row.valueTone(v.temp.tone));
                        case "failed": return row.color(row.stale ? "stale" : v.failed.n > 0 ? "danger" : "quiet");
                        case "up":
                            if (v.status === "paused" || v.status === "pending") return row.color("muted");
                            if (v.status === "down") return row.color(v.tone);
                            return row.color(row.stale ? "stale" : "normal");
                        case "notes": return row.color(noteReason ? noteReason.tone : "quiet");
                        case "why": return row.color(topReason ? topReason.tone : "quiet");
                        }
                        return row.color("normal");
                    }
                }
            }
        }
    }
}
