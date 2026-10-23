import Quickshell
import QtQuick
import "builder-gate.js" as Gate

// The remote-builder control in the top bar: two targets side by side.
//
//   [● Builds on][▾]
//
// The left target is the state and the one-click toggle: a click sets a
// manual choice the other way. The right target opens the panel, which also
// holds "use default" and "stop now". A right-click on either opens the
// panel too. A manual choice draws a thin outline around both, a latch that
// stays until myoko joins another network.
//
// The words are a readout and shorten on a narrow bar (Gate.barPlan); the
// mark, the latch and both targets stay at every width, and the tooltip
// keeps the full words.
Item {
    id: root

    required property var gate
    required property real barWidth
    property bool panelOpen: false
    signal panelRequested

    readonly property var plan: Gate.barPlan(barWidth)
    readonly property string toneName: Gate.tone(gate.sample, gate.pending, gate.actionError)
    readonly property color toneColor: ({
        accent: Theme.accent,
        primary: Theme.textPrimary,
        muted: Theme.textMuted,
        warning: Theme.warning,
        quiet: Theme.textMuted
    })[toneName]
    readonly property string markName: Gate.mark(gate.sample, gate.pending)

    implicitWidth: main.implicitWidth + opener.implicitWidth
    implicitHeight: 26

    function press(mouse) {
        if (mouse.button === Qt.RightButton) root.panelRequested();
        else if (Gate.clickAction(root.gate.sample, root.gate.pending) === "panel") root.panelRequested();
        else root.gate.toggle();
    }

    Rectangle {
        id: main
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        implicitWidth: row.implicitWidth + 12
        width: implicitWidth
        topLeftRadius: Theme.radiusSmall
        bottomLeftRadius: Theme.radiusSmall
        color: mainArea.pressed ? Theme.bgActive
            : mainArea.containsMouse ? Theme.bgSelected : "transparent"

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 5

            // On: a filled dot. Off: a ring. No mark without a valid status.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.markName !== "none"
                text: root.markName === "on" ? "●" : "○"
                color: root.toneColor
                font.pixelSize: 9
                font.family: Theme.fontFamily
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: Gate.barText(root.gate.sample, root.gate.pending, root.gate.actionError, root.plan.form)
                color: root.toneColor
                font.pixelSize: 10
                font.family: Theme.fontFamily
            }
        }

        MouseArea {
            id: mainArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function (mouse) { root.press(mouse); }
        }
    }

    Rectangle {
        id: opener
        anchors.left: main.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        implicitWidth: 16
        width: implicitWidth
        topRightRadius: Theme.radiusSmall
        bottomRightRadius: Theme.radiusSmall
        color: root.panelOpen || openerArea.pressed ? Theme.bgActive
            : openerArea.containsMouse ? Theme.bgSelected : "transparent"

        // A hairline between the two targets, so they read as two.
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 12
            color: Theme.bgSeparator
        }

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 1
            text: "▾"
            color: Theme.textMuted
            font.pixelSize: 10
            font.family: Theme.fontFamily
        }

        MouseArea {
            id: openerArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.panelRequested()
        }
    }

    // The latch: a manual choice is in force.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        visible: Gate.latched(root.gate.sample) && !root.gate.pending
        color: "transparent"
        radius: Theme.radiusSmall
        border.width: 1
        border.color: root.toneColor
        opacity: 0.6
    }

    // The tooltip says why, and what a click does. It waits half a second,
    // so passing over the bar does not flash it.
    Timer {
        id: hoverDelay
        interval: 500
        running: mainArea.containsMouse && !root.panelOpen
    }

    PopupWindow {
        id: tip
        visible: mainArea.containsMouse && !mainArea.pressed && !hoverDelay.running && !root.panelOpen
        anchor.item: root
        anchor.rect.x: 0
        // Quickshell's defaults: the popup grows down and right from the
        // point below the control, and the compositor slides it back on
        // screen near the right edge.
        anchor.rect.y: root.height + 4
        implicitWidth: Math.min(440, tipText.implicitWidth + 20)
        implicitHeight: tipText.implicitHeight + 14
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: Theme.bgPanel
            border.width: 1
            border.color: Theme.borderMuted

            Text {
                id: tipText
                x: 10
                y: 7
                width: Math.min(420, implicitWidth)
                text: Gate.tooltip(root.gate.sample, root.gate.pending, root.gate.actionError).join("\n")
                color: Theme.textSecondary
                wrapMode: Text.Wrap
                lineHeight: 1.15
                font.pixelSize: 10
                font.family: Theme.fontFamily
            }
        }
    }
}
