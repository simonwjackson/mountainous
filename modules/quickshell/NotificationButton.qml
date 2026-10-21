import QtQuick

// One notification control: an action, Dismiss all, Retry. The drawn size
// follows the label; the hit area never drops below 28 px tall.
//
// A label never gets cut. Past maxWidth it wraps, and the button grows
// taller, so an app's long action name is always readable in full.
Rectangle {
    id: root

    property string text: ""
    // Shown before the label while the keyboard can reach this button by
    // number, so the key is never a guess.
    property string keyHint: ""
    property bool quiet: false
    // The keyboard's current action in the centre.
    property bool focused: false
    property real maxWidth: 400
    signal clicked

    readonly property bool hovered: area.containsMouse
    readonly property int padX: 10

    implicitWidth: Math.min(maxWidth, label.implicitWidth + 2 * padX)
    implicitHeight: Math.max(26, label.contentHeight + 10)
    radius: Theme.radiusSmall
    color: {
        if (!root.enabled) return "transparent";
        if (area.pressed) return Theme.bgActive;
        if (area.containsMouse) return Theme.bgSelected;
        return root.quiet ? "transparent" : Theme.bgInput;
    }
    border.width: root.focused ? 2 : 1
    border.color: root.focused || (root.enabled && area.pressed) ? Theme.accent
        : root.enabled ? Theme.borderMuted : Theme.bgSelected

    Text {
        id: label
        x: root.padX
        width: root.width - 2 * root.padX
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: lineCount > 1 ? Text.AlignLeft : Text.AlignHCenter
        wrapMode: Text.Wrap
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
