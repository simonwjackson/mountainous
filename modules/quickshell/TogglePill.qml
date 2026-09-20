import QtQuick

Item {
    id: root

    required property bool checked
    signal toggled(bool checked)

    implicitWidth: 42
    implicitHeight: 30

    Rectangle {
        anchors.centerIn: parent
        width: 34
        height: 18
        radius: 9
        color: root.checked ? Theme.accent : Theme.bgSeparator
        opacity: root.enabled ? 1.0 : 0.45

        Rectangle {
            width: 14
            height: 14
            radius: 7
            y: 2
            x: root.checked ? parent.width - width - 2 : 2
            color: Theme.textPrimary

            Behavior on x {
                NumberAnimation { duration: 100 }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.toggled(!root.checked)
    }
}
