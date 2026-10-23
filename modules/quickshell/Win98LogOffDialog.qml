import QtQuick

// "Are you sure you want to log off?" Log Off from the Start menu asks
// first (Super+Shift+E still exits at once). Yes ends the Hyprland session.
Win98Window {
    id: root

    required property var desktop

    title: desktop.hostLabel === "" ? "Log Off" : "Log Off " + desktop.hostLabel
    margins: false
    onCloseClicked: MenuState.close()

    Item {
        x: 12 * root.u; y: 10 * root.u
        width: root.bodyWidth - 24 * root.u
        // 10 u in, the question, 6 u and 8 u, the buttons, 10 u out.
        implicitHeight: 10 * root.u + 24 * root.u + 14 * root.u + 23 * root.u + 10 * root.u
        Win98Icon { name: "logoff" }
        Win98Text {
            x: 36 * root.u
            y: Win98Tokens.snap((24 * root.u - height) / 2, root.u)
            width: Math.min(implicitWidth, parent.width - x)
            text: "Are you sure you want to log off?"
            accessMarks: false
        }
        Row {
            x: Win98Tokens.half((parent.width - width) / 2, root.u)
            y: 38 * root.u
            spacing: 6 * root.u
            Win98Button { id: yes; text: "&Yes"; isDefault: true; focus: true; onClicked: root.desktop.logOff() }
            Win98Button { text: "&No"; onClicked: MenuState.close() }
        }
    }

    Shortcut { sequence: "Y"; context: Qt.WindowShortcut; onActivated: root.desktop.logOff() }
    Shortcut { sequence: "N"; context: Qt.WindowShortcut; onActivated: MenuState.close() }
}
