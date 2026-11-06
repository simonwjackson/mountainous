pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import QtQuick
import "themes/memphis/tray-model.js" as Tray

// The glance space's Disks accessory in the Memphis form: the shared
// StorageHealth owner's findings (the same data as the tray's Server
// storage window and Platinum's Disks widget), as a list of marks, hosts
// and messages in a white well. Problems come first; a long finding wraps.
// The status bar says how old the check is.
FocusScope {
    id: view

    required property var panel          // panels/StorageHealth.qml
    signal escapePressed

    readonly property real u: Kit.MemphisTokens.unitFor(QsWindow.window)
    function units(n) { return n * view.u; }

    // The window's own width at rest, in logical px (230 u, the mock's).
    readonly property real naturalWidth: units(230)
    readonly property int chromeH: Kit.MemphisTokens.frame + Kit.MemphisTokens.captionHeight + 1 + Kit.MemphisTokens.frame

    readonly property var rows: {
        const out = [];
        const list = view.panel.rows || [];
        for (const r of list) if (r.level !== "ok") out.push(r);
        for (const r of list) if (r.level === "ok") out.push(r);
        return out;
    }
    readonly property var hosts: {
        const seen = {};
        for (const r of view.panel.issues || []) seen[r.host] = true;
        return Object.keys(seen);
    }
    readonly property string summary: !view.panel.enabled ? "Storage checks are off here"
        : view.panel.state === "loading" ? "Checking the servers..."
        : view.panel.state === "error" && view.rows.length === 0 ? "The check did not run"
        : view.panel.issues.length === 0 ? "No findings"
        : view.panel.issues.length + (view.panel.issues.length === 1 ? " finding" : " findings")
            + " on " + view.hosts.length + (view.hosts.length === 1 ? " host" : " hosts")
    readonly property string tone: !view.panel.enabled ? "muted" : view.panel.tone === "quiet" ? "normal" : view.panel.tone
    function levelTone(level) { return level === "bad" ? "danger" : level === "ok" ? "normal" : "warning"; }
    function ink(tone) {
        return tone === "danger" ? Kit.MemphisTokens.danger : tone === "warning" ? Kit.MemphisTokens.warning
            : tone === "muted" ? Kit.MemphisTokens.gray : Kit.MemphisTokens.text;
    }

    // Heights in logical px: the summary, the list (its rows' natural
    // height, at least one line), the status bar.
    readonly property real headH: units(22)
    readonly property real listNatural: Math.max(rowsColumn.implicitHeight, units(18)) + units(4)
    property real maxFrameHeight: -1
    readonly property real fixedH: units(chromeH) + headH + units(4 + 22)
    readonly property real listH: maxFrameHeight >= 0 ? Math.max(units(22), Math.min(listNatural, maxFrameHeight - fixedH)) : listNatural
    implicitWidth: naturalWidth - units(2 * Kit.MemphisTokens.frame)
    implicitHeight: headH + listH + units(2 + 22)
    readonly property real restHeight: units(chromeH) + headH + listNatural + units(2 + 22)

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) { view.escapePressed(); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { list.contentY = Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + view.units(16)); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { list.contentY = Math.max(0, list.contentY - view.units(16)); event.accepted = true; }
    }

    Row {
        x: view.units(4)
        y: view.units(3)
        spacing: view.units(4)
        MemphisIcon { name: Tray.diskIcon(view.panel.state, view.panel.worst) }
        MemphisText {
            y: view.units(2)
            width: Math.min(implicitWidth, view.width - view.units(28))
            text: view.summary
            accessMarks: false
            color: view.ink(view.tone)
        }
    }

    MemphisBevel {
        id: well
        x: view.units(2)
        y: view.headH
        width: parent.width - view.units(4)
        height: view.listH
        variant: "field"
        color: Kit.MemphisTokens.win

        Flickable {
            id: list
            x: view.units(2)
            y: view.units(2)
            width: well.width - view.units(4) - (bar.visible ? bar.width : 0)
            height: well.height - view.units(4)
            clip: true
            interactive: false
            contentHeight: rowsColumn.implicitHeight
            WheelHandler {
                enabled: list.contentHeight > list.height
                onWheel: event => list.contentY = Math.max(0, Math.min(list.contentHeight - list.height,
                    list.contentY - Math.sign(event.angleDelta.y) * view.units(16)))
            }
            Column {
                id: rowsColumn
                width: list.width
                MemphisText {
                    visible: view.rows.length === 0
                    x: view.units(4)
                    width: parent.width - view.units(8)
                    wrap: true
                    accessMarks: false
                    color: Kit.MemphisTokens.gray
                    text: !view.panel.enabled ? "This desktop does not run the storage checks."
                        : view.panel.state === "loading" ? "Asking each server over SSH." : "Nothing to show yet."
                }
                Repeater {
                    model: view.rows
                    Item {
                        id: finding
                        required property var modelData
                        width: rowsColumn.width
                        height: Math.max(view.units(16), message.implicitHeight + view.units(2))
                        MemphisIcon {
                            x: view.units(2)
                            y: view.units(2)
                            name: finding.modelData.level === "ok" ? "ok" : finding.modelData.level === "bad" ? "bad" : "warn"
                        }
                        MemphisText {
                            id: hostName
                            x: view.units(17)
                            y: view.units(1)
                            width: view.units(46)
                            text: finding.modelData.host
                            accessMarks: false
                            color: finding.modelData.level === "ok" ? Kit.MemphisTokens.winText : view.ink(view.levelTone(finding.modelData.level))
                        }
                        MemphisText {
                            id: message
                            x: view.units(17 + 46 + 3)
                            y: view.units(1)
                            width: finding.width - x - view.units(2)
                            wrap: true
                            accessMarks: false
                            text: finding.modelData.message
                            color: finding.modelData.level === "ok" ? Kit.MemphisTokens.gray : Kit.MemphisTokens.winText
                        }
                    }
                }
            }
        }
        MemphisScrollBar {
            id: bar
            visible: list.contentHeight > list.height + 0.5
            x: well.width - view.units(2) - width
            y: view.units(2)
            height: well.height - view.units(4)
            flickable: list
            step: view.units(16)
        }
    }

    Item {
        y: well.y + well.height + view.units(2)
        width: parent.width
        height: view.units(18)
        MemphisBevel { anchors.fill: parent; variant: "thinSunken"; filled: false }
        MemphisText {
            x: view.units(4)
            y: view.units(3)
            width: Math.min(implicitWidth, parent.width - view.units(8))
            text: (view.panel.enabled ? view.panel.statusText : "Same data as the Server storage window").replace(/\u2026/g, "...")
            accessMarks: false
            color: view.panel.state === "error" || view.panel.state === "stale" ? Kit.MemphisTokens.warning : Kit.MemphisTokens.gray
        }
    }
}
