pragma ComponentBehavior: Bound

import Hensou as Kit
import QtQuick

// Server storage as a Memphis tree view: each host, then its findings with
// their level's mark and colour. Long findings wrap. The shared
// StorageHealth owns the check and its results.
MemphisWindow {
    id: root

    required property var panel

    title: "Server storage"
    iconName: "disk-ok"
    onCloseClicked: MenuState.close()

    // A short screen: the findings list gives up height first (down to two
    // rows), then the status bar goes; the body scrolls only after that.
    readonly property real listNatural: 120 * u
    readonly property real listMin: 40 * u
    // Measured after layout settles, not bound: the list's height feeds
    // the window's own height, so a binding would loop. The sum is a fixed
    // point (what the list gives up, it adds back).
    property real natural: 0
    Timer {
        id: naturalMeasure
        interval: 0
        onTriggered: root.measureNatural()
    }
    function measureNatural() { root.natural = implicitHeight + (well.visible ? listNatural - well.height : 0) + (statusArea.visible ? 0 : 26 * u); }
    Connections {
        target: root
        function onImplicitHeightChanged() { naturalMeasure.restart(); }
    }
    Component.onCompleted: naturalMeasure.restart()
    readonly property real squeeze: availableHeight > 0 ? Math.max(0, natural - availableHeight) : 0
    readonly property bool dropStatus: squeeze > (well.visible ? listNatural - listMin : 0) + 0.5
    readonly property real listHeight: Math.max(listMin, Math.floor((listNatural - squeeze) / u) * u)

    // Host rows and finding rows, in order.
    readonly property var lines: {
        const out = [];
        let host = null;
        for (const r of panel.rows) {
            if (r.host !== host) { host = r.host; out.push({ kind: "host", text: host }); }
            out.push({ kind: "finding", text: r.message, level: r.level });
        }
        return out;
    }

    Column {
        id: body
        width: root.bodyWidth
        spacing: 6 * root.u

        Item {
            width: parent.width
            height: Math.max(21 * root.u, status.height)
            MemphisText {
                id: status
                y: Math.max(0, Kit.MemphisTokens.snap((21 * root.u - height) / 2, root.u))
                width: parent.width - check.width - 6 * root.u
                wrap: true
                text: root.panel.statusText.replace(/\u2026/g, "...")
                accessMarks: false
                color: root.panel.state === "error" || root.panel.state === "stale" ? Kit.MemphisTokens.warning : Kit.MemphisTokens.text
            }
            MemphisButton {
                id: check
                x: parent.width - width
                small: true
                text: root.panel.checking ? "Checking" : "&Check now"
                enabled: !root.panel.checking
                onClicked: root.panel.refresh()
            }
        }

        MemphisBevel {
            id: well
            visible: root.lines.length > 0
            width: parent.width
            height: root.listHeight
            variant: "field"
            color: Kit.MemphisTokens.win
            Flickable {
                id: tree
                x: 2 * root.u; y: 2 * root.u
                width: well.width - 4 * root.u - (bar.visible ? 18 * root.u : 0)
                height: well.height - 4 * root.u
                clip: true
                interactive: false
                contentHeight: rows.height
                Column {
                    id: rows
                    width: tree.width
                    Repeater {
                        model: root.lines
                        Item {
                            id: line
                            required property var modelData
                            readonly property bool host: modelData.kind === "host"
                            width: rows.width
                            height: Math.max(16 * root.u, (host ? 16 * root.u : msg.height + 2 * root.u))
                            // [−] host
                            Rectangle {
                                visible: line.host
                                x: 3 * root.u; y: Kit.MemphisTokens.snap((line.height - height) / 2, root.u)
                                width: 9 * root.u; height: 9 * root.u
                                color: Kit.MemphisTokens.win
                                border.width: root.u
                                border.color: Kit.MemphisTokens.gray
                                Rectangle { x: 2 * root.u; y: 4 * root.u; width: 5 * root.u; height: root.u; color: Kit.MemphisTokens.winText }
                            }
                            MemphisIcon {
                                visible: line.host
                                name: "host"
                                x: 16 * root.u; y: Kit.MemphisTokens.snap((line.height - height) / 2, root.u)
                            }
                            MemphisIcon {
                                visible: !line.host
                                name: line.modelData.level === "ok" ? "ok" : line.modelData.level === "bad" ? "bad" : "warn"
                                x: 18 * root.u; y: 2 * root.u
                            }
                            MemphisText {
                                id: msg
                                x: line.host ? 36 * root.u : 34 * root.u
                                y: line.host ? Kit.MemphisTokens.snap((line.height - height) / 2, root.u) : root.u
                                width: line.host ? Math.min(implicitWidth, line.width - x) : line.width - x - 3 * root.u
                                wrap: !line.host
                                text: line.modelData.text
                                accessMarks: false
                                color: line.host ? Kit.MemphisTokens.winText : line.modelData.level === "bad" ? Kit.MemphisTokens.danger
                                    : line.modelData.level === "ok" ? Kit.MemphisTokens.winText : Kit.MemphisTokens.warning
                            }
                        }
                    }
                }
            }
            MemphisScrollBar {
                id: bar
                visible: tree.contentHeight > tree.height + 0.5
                x: well.width - 2 * root.u - width
                y: 2 * root.u
                height: well.height - 4 * root.u
                flickable: tree
                step: 17 * root.u
            }
        }

        Item {
            id: statusArea
            visible: !root.dropStatus
            width: parent.width
            height: 20 * root.u
            MemphisStatusBar {
                y: 2 * root.u
                width: parent.width
                panes: ["Esc or click outside to close"]
            }
        }
    }
}
