import QtQuick

// One notification control: an action, Dismiss all, Retry. The drawn size
// follows the label; the hit area never drops below 28 px tall.
Rectangle {
    id: root

    property string text: ""
    // Shown before the label while the keyboard can reach this button by
    // number, so the key is never a guess.
    property string keyHint: ""
    property bool quiet: false
    property real maxWidth: 400
    signal clicked

    readonly property bool hovered: area.containsMouse

    implicitWidth: Math.min(maxWidth, label.implicitWidth + 20)
    implicitHeight: 26
    radius: Theme.radiusSmall
    color: {
        if (!root.enabled) return "transparent";
        if (area.pressed) return Theme.bgActive;
        if (area.containsMouse) return Theme.bgSelected;
        return root.quiet ? "transparent" : Theme.bgInput;
    }
    border.width: 1
    border.color: root.enabled ? Theme.borderMuted : Theme.bgSelected

    Text {
        id: label
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: root.keyHint !== "" ? root.keyHint + "  " + root.text : root.text
        color: root.enabled ? Theme.accent : Theme.textOff
        font.pixelSize: 11
        font.family: Theme.fontFamily
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: Math.min(0, (root.height - 28) / 2)
        anchors.bottomMargin: Math.min(0, (root.height - 28) / 2)
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
