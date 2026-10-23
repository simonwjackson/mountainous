import QtQuick

// A Platinum check box: a sunken well with a black edge and a check mark.
// The box sits centred in the menu gutter (MenuCheckRow), so its label
// starts on the text edge like every other row.
Item {
    id: root

    property bool checked: false
    property bool down: false
    signal toggled(bool checked)

    implicitWidth: 14
    implicitHeight: 14

    Bevel {
        anchors.fill: parent
        sunken: true
        color: root.down ? Theme.bevelDark : Theme.well
        lightColor: Theme.bevelLight
        darkColor: Theme.bevelDark
    }

    PlatinumIcon {
        anchors.centerIn: parent
        visible: root.checked
        name: "check"
        size: 10
        color: root.enabled ? Theme.menuText : Theme.menuTextOff
    }
}
