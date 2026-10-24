import QtQuick

// The glance space's Disks widget: the shared StorageHealth owner's
// findings (the same data as the bar's Disks menu), styled as a Finder
// list in a windoid. Problems come first; a long finding wraps.
FocusScope {
    id: view

    required property var panel          // panels/StorageHealth.qml
    property real frameHeight: -1        // the windoid's height; -1 natural
    property real maxFrameHeight: -1     // the most it may take; -1 no limit
    property real frameChromeHeight: 16 + 5 * h
    signal escapePressed

    readonly property real h: PlatinumTokens.hair
    readonly property real infoH: 24
    readonly property real footH: h + 15
    readonly property real naturalWidth: 300
    implicitWidth: naturalWidth

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
        : view.panel.state === "loading" ? "Checking the servers…"
        : view.panel.state === "error" && view.rows.length === 0 ? "The check did not run"
        : view.panel.issues.length === 0 ? "No findings"
        : view.panel.issues.length + (view.panel.issues.length === 1 ? " finding" : " findings")
            + " on " + view.hosts.length + (view.hosts.length === 1 ? " host" : " hosts")
    readonly property string tone: !view.panel.enabled ? "muted" : view.panel.tone === "quiet" ? "normal" : view.panel.tone
    function levelTone(level) { return level === "bad" ? "danger" : level === "ok" ? "normal" : "warning"; }
    function toneColor(tone) {
        return tone === "danger" ? PlatinumTokens.menuDanger : tone === "warning" ? PlatinumTokens.menuWarning
            : tone === "muted" ? PlatinumTokens.menuTextSecondary : PlatinumTokens.menuText;
    }

    readonly property real listContentH: Math.max(rowsColumn.implicitHeight, 22)
    readonly property real fixedH: frameChromeHeight + infoH + h + footH
    readonly property real listH: frameHeight >= 0 ? Math.max(0, frameHeight - fixedH)
        : maxFrameHeight >= 0 ? Math.max(0, Math.min(listContentH, maxFrameHeight - fixedH)) : listContentH
    readonly property real bodyHeight: infoH + h + listH + footH
    readonly property real restBodyHeight: infoH + h + listContentH + footH
    implicitHeight: bodyHeight

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) { view.escapePressed(); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { list.contentY = Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + 22); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { list.contentY = Math.max(0, list.contentY - 22); event.accepted = true; }
    }

    Item {
        id: info
        width: parent.width
        height: view.infoH
        Rectangle { width: parent.width; height: view.h; color: PlatinumTokens.bevelLight }
        Rectangle { y: parent.height - view.h; width: parent.width; height: view.h; color: PlatinumTokens.bevelDark }
        PlatinumStatusLight {
            id: light
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            shape: !view.panel.enabled || view.panel.state === "error" ? "down" : view.panel.state === "loading" ? "pending" : "up"
            tone: view.tone
        }
        Text {
            x: light.x + light.width + 7
            width: parent.width - x - 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: view.summary
            textFormat: Text.PlainText
            color: view.toneColor(view.tone === "normal" ? "normal" : view.tone)
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumSmall
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
    }

    Rectangle { y: view.infoH; width: parent.width; height: view.h; color: PlatinumTokens.menuEdge }

    Rectangle {
        y: view.infoH + view.h
        width: parent.width
        height: view.listH
        color: PlatinumGlanceTokens.listSurface
    }

    Flickable {
        id: list
        y: view.infoH + view.h
        width: parent.width - (scroll.visible ? scroll.width : 0)
        height: view.listH
        clip: true
        contentHeight: view.listContentH
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: rowsColumn
            width: list.width
            topPadding: 2
            bottomPadding: 2

            Text {
                visible: view.rows.length === 0
                x: 30
                width: parent.width - x - 10
                height: 22
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                text: !view.panel.enabled ? "This desktop does not run the storage checks."
                    : view.panel.state === "loading" ? "Asking each server over SSH." : "Nothing to show yet."
                color: PlatinumTokens.menuTextSecondary
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }

            Repeater {
                model: view.rows
                Item {
                    required property var modelData
                    width: rowsColumn.width
                    height: PlatinumMetrics.even(Math.max(22, line.implicitHeight + 8))
                    PlatinumStatusLight {
                        x: 6 + (20 - width) / 2
                        y: (22 - height) / 2
                        size: 11
                        shape: modelData.level === "unreachable" ? "down" : "up"
                        tone: view.levelTone(modelData.level)
                    }
                    Text {
                        id: line
                        x: 30
                        y: 4
                        width: parent.width - x - 10
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        // Display data from the hosts: escaped before it is styled.
                        function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
                        text: '<font color="' + view.toneColor(modelData.level === "ok" ? "muted" : view.levelTone(modelData.level))
                            + '">' + esc(modelData.host) + '</font> ' + esc(modelData.message)
                        color: modelData.level === "ok" ? PlatinumTokens.menuTextSecondary : PlatinumTokens.menuText
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                        font.letterSpacing: PlatinumTokens.platinumTracking
                        lineHeight: 1.1
                    }
                }
            }
        }
    }

    PlatinumScrollBar {
        id: scroll
        flickable: list
        x: parent.width - width
        y: view.infoH + view.h
        height: view.listH
    }

    Item {
        y: view.infoH + view.h + view.listH
        width: parent.width
        height: view.footH
        Rectangle { width: parent.width; height: view.h; color: PlatinumTokens.menuEdge }
        Text {
            x: 8
            y: view.h + (15 - height) / 2
            width: parent.width - 16
            elide: Text.ElideRight
            text: view.panel.enabled ? view.panel.statusText : "Same data as the Disks menu"
            color: view.panel.state === "error" || view.panel.state === "stale" ? PlatinumTokens.menuWarning : PlatinumTokens.menuTextSecondary
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumHint
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
    }
}
