import QtQuick

// A Win98 check box: a 13-u sunken white box with a 7-u check, the label
// 5 u to its right. Disabled: a face-coloured box, a grey check and a grey
// embossed label. Focus: a dotted rectangle around the label. Space or a
// click toggles; the owner sets checked from toggled().
FocusScope {
    id: root

    property string text: ""           // "&" marks the access key
    property bool checked: false
    property bool showFocus: false
    property bool showPressed: false

    signal toggled

    readonly property real u: Win98Tokens.u
    readonly property bool pressing: showPressed || (area.pressed && area.containsMouse)

    implicitWidth: Win98Tokens.checkBox * u + (text !== "" ? 5 * u + label.implicitWidth : 0)
    implicitHeight: Win98Tokens.checkBox * u
    activeFocusOnTab: enabled

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space) {
            root.toggled();
            event.accepted = true;
        }
    }

    Win98Bevel {
        id: box
        width: Win98Tokens.checkBox * root.u
        height: width
        variant: "field"
        // Win98 greys the box while the pointer holds it, and when disabled.
        color: root.enabled && !root.pressing ? Win98Tokens.win : Win98Tokens.face

        Win98Icon {
            visible: root.checked
            x: 3 * root.u; y: 3 * root.u
            name: "check"
            color: root.enabled ? Win98Tokens.winText : Win98Tokens.gray
        }
    }

    Win98Text {
        id: label
        visible: root.text !== ""
        x: box.width + 5 * root.u
        width: Math.min(implicitWidth, root.width - x)
        text: root.text
        disabledLook: !root.enabled
    }

    Win98FocusRect {
        visible: root.enabled && root.text !== "" && (root.showFocus || root.activeFocus)
        x: label.x - root.u; y: -root.u
        width: label.width + 2 * root.u
        height: label.height + 2 * root.u
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        onPressed: root.forceActiveFocus()
        onClicked: root.toggled()
    }
}
