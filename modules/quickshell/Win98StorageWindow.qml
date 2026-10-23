pragma ComponentBehavior: Bound

import QtQuick

// Server storage as a Win98 tree view: each host, then its findings with
// their level's mark and colour. Long findings wrap. The shared
// StorageHealth owns the check and its results.
Win98Window {
    id: root

    required property var panel

    title: "Server storage"
    iconName: "disk-ok"
    onCloseClicked: MenuState.close()

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
        width: root.width - 22 * root.u
        spacing: 6 * root.u

        Item {
            width: parent.width
            height: Math.max(21 * root.u, status.height)
            Win98Text {
                id: status
                y: Math.max(0, Win98Tokens.snap((21 * root.u - height) / 2))
                width: parent.width - check.width - 6 * root.u
                wrap: true
                text: root.panel.statusText.replace(/\u2026/g, "...")
                accessMarks: false
                color: root.panel.state === "error" || root.panel.state === "stale" ? Win98Tokens.warning : Win98Tokens.text
            }
            Win98Button {
                id: check
                x: parent.width - width
                small: true
                text: root.panel.checking ? "Checking" : "&Check now"
                enabled: !root.panel.checking
                onClicked: root.panel.refresh()
            }
        }

        Win98Bevel {
            id: well
            visible: root.lines.length > 0
            width: parent.width
            height: 120 * root.u
            variant: "field"
            color: Win98Tokens.win
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
                                x: 3 * root.u; y: Win98Tokens.snap((line.height - height) / 2)
                                width: 9 * root.u; height: 9 * root.u
                                color: Win98Tokens.win
                                border.width: root.u
                                border.color: Win98Tokens.gray
                                Rectangle { x: 2 * root.u; y: 4 * root.u; width: 5 * root.u; height: root.u; color: Win98Tokens.winText }
                            }
                            Win98Icon {
                                visible: line.host
                                name: "host"
                                x: 16 * root.u; y: Win98Tokens.snap((line.height - height) / 2)
                            }
                            Win98Icon {
                                visible: !line.host
                                name: line.modelData.level === "ok" ? "ok" : line.modelData.level === "bad" ? "bad" : "warn"
                                x: 18 * root.u; y: 2 * root.u
                            }
                            Win98Text {
                                id: msg
                                x: line.host ? 36 * root.u : 34 * root.u
                                y: line.host ? Win98Tokens.snap((line.height - height) / 2) : root.u
                                width: line.host ? Math.min(implicitWidth, line.width - x) : line.width - x - 3 * root.u
                                wrap: !line.host
                                text: line.modelData.text
                                accessMarks: false
                                color: line.host ? Win98Tokens.winText : line.modelData.level === "bad" ? Win98Tokens.danger
                                    : line.modelData.level === "ok" ? Win98Tokens.winText : Win98Tokens.warning
                            }
                        }
                    }
                }
            }
            Win98ScrollBar {
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
            width: parent.width
            height: 20 * root.u
            Win98StatusBar {
                y: 2 * root.u
                width: parent.width
                panes: ["Esc or click outside to close"]
            }
        }
    }
}
