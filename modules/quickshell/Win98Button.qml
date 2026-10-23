import QtQuick

// A Win98 push button: 23 u tall (21 u small), at least 75 u wide, its
// label centred. Buttons that share a role share a width: pass the role's
// longest label in roleLabels (or a fixed width in units), so a column of
// Connect / Disconnect / Pair starts and ends on one edge.
//
// States: default (black ring, Enter runs it), disabled (grey embossed
// label), pressed (ring and a grey line; the label moves 1 u down and
// right), focus (dotted rectangle 4 u inside). Space and Enter click it.
FocusScope {
    id: root

    property string text: ""          // "&" marks the access key
    property string iconName: ""
    property bool isDefault: false
    property bool small: false
    property var roleLabels: []
    property real widthUnits: 0       // fixed width; 0 = from the label
    // Draw a state without the pointer or the keyboard (galleries, a host
    // that drives the button by its own keys).
    property bool showPressed: false
    property bool showFocus: false

    signal clicked

    readonly property real u: Win98Tokens.u
    readonly property bool down: showPressed || (area.pressed && area.containsMouse) || keyDown
    readonly property bool focusShown: enabled && (showFocus || activeFocus)
    readonly property real padUnits: small ? 7 : 8
    property bool keyDown: false

    readonly property real labelWidth: Math.max(
        Win98Tokens.textWidth(Win98Tokens.plainText(text), false),
        Win98Tokens.widest(roleLabels.map(Win98Tokens.plainText), false))
        + (iconName !== "" ? 16 * u + (text !== "" ? 4 * u : 0) : 0)

    implicitWidth: widthUnits > 0 ? widthUnits * u
        : Math.max(small ? 0 : Win98Tokens.buttonMinWidth * u, Win98Tokens.ceilU(labelWidth) + 2 * padUnits * u)
    implicitHeight: (small ? Win98Tokens.buttonSmallHeight : Win98Tokens.buttonHeight) * u
    activeFocusOnTab: enabled

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyDown = event.key === Qt.Key_Space;
            if (event.key !== Qt.Key_Space) root.clicked();
            event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Space && root.keyDown) {
            root.keyDown = false;
            root.clicked();
            event.accepted = true;
        }
    }

    Win98Bevel {
        anchors.fill: parent
        variant: root.down ? "defaultPressed" : root.isDefault && root.enabled ? "default" : "button"
    }

    Row {
        id: content
        spacing: 4 * root.u
        x: Win98Tokens.snap((root.width - width) / 2) + (root.down ? root.u : 0)
        y: Win98Tokens.snap((root.height - height) / 2) + (root.down ? root.u : 0)

        Win98Icon {
            visible: root.iconName !== ""
            name: root.iconName
            opacity: root.enabled ? 1 : 0.5
        }
        Win98Text {
            visible: root.text !== ""
            y: Win98Tokens.snap((content.height - height) / 2)
            text: root.text
            disabledLook: !root.enabled
            width: Math.min(implicitWidth, root.width - 2 * root.padUnits * root.u)
        }
    }

    Win98FocusRect {
        visible: root.focusShown
        x: 4 * root.u; y: 4 * root.u
        width: root.width - 8 * root.u
        height: root.height - 8 * root.u
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        onPressed: root.forceActiveFocus()
        onClicked: root.clicked()
    }
}
