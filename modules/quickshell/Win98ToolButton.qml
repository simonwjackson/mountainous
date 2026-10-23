import Quickshell
import QtQuick

// A flat toolbar or tray button, as IE4 brought to Win98's toolbars: flat
// at rest, a thin raised edge on hover, a thin sunken edge while pressed
// or while its window is open, sunken over the dither while latched
// (checked). Square around an icon (22 u, or 20 u in the tray), wider when
// it has text. A count badge sits on the top-right corner.
FocusScope {
    id: root

    property string iconName: ""
    property string text: ""
    property color iconColor: Win98Tokens.text
    property bool tray: false
    property bool checked: false        // latched
    property bool open: false           // its window or menu is open
    property string badge: ""
    property bool showHover: false
    property bool showPressed: false
    property bool showFocus: false

    signal clicked

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property real side: (tray ? Win98Tokens.trayButton : Win98Tokens.toolButton) * u
    readonly property bool hovered: showHover || area.containsMouse
    readonly property bool pressing: showPressed || (area.pressed && area.containsMouse)
    readonly property bool sunken: pressing || open || checked

    implicitWidth: text === "" ? side
        : Win98Tokens.ceilU((iconName !== "" ? 16 * u + 3 * u : 0) + Win98Tokens.textWidth(Win98Tokens.plainText(text), false, root.u), root.u) + 7 * u
    implicitHeight: side
    activeFocusOnTab: enabled

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Win98Tokens.face
    }
    Win98Dither {
        visible: root.checked && !root.open && !root.pressing
        anchors.fill: parent
        anchors.margins: root.u
    }
    Win98Bevel {
        anchors.fill: parent
        filled: false
        visible: root.enabled && (root.sunken || root.hovered)
        variant: root.sunken ? "thinSunken" : "thinRaised"
    }

    Row {
        spacing: 3 * root.u
        x: (root.text === "" ? Win98Tokens.snap((root.width - width) / 2, root.u) : 3 * root.u) + (root.pressing ? root.u : 0)
        y: Win98Tokens.snap((root.height - height) / 2, root.u) + (root.pressing ? root.u : 0)

        Win98Icon {
            visible: root.iconName !== ""
            name: root.iconName
            color: root.enabled ? root.iconColor : Win98Tokens.gray
            opacity: root.enabled ? 1 : 0.5
        }
        Win98Text {
            visible: root.text !== ""
            y: Win98Tokens.snap((root.height - height) / 2, root.u) - parent.y + (root.pressing ? root.u : 0)
            text: root.text
            disabledLook: !root.enabled
            width: Math.min(implicitWidth, root.width - 7 * root.u - (root.iconName !== "" ? 19 * root.u : 0))
        }
    }

    // A count in a 3x5 pixel face: the UI font does not fit on a 16-u icon.
    Win98Badge {
        visible: root.badge !== ""
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.badge
    }

    Win98FocusRect {
        visible: root.enabled && (root.showFocus || root.activeFocus)
        x: root.u; y: root.u
        width: root.width - 2 * root.u
        height: root.height - 2 * root.u
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
