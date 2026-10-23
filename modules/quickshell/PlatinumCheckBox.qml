import QtQuick

// A Platinum check box: a sunken well with a black edge and a check mark.
// The box sits centred in the menu gutter (PlatinumMenuCheckRow), so its label
// starts on the text edge like every other row.
Item {
    id: root

    property bool checked: false
    property bool down: false
    signal toggled(bool checked)

    implicitWidth: 14
    implicitHeight: 14

    PlatinumBevel {
        anchors.fill: parent
        sunken: true
        color: root.down ? PlatinumTokens.bevelDark : PlatinumTokens.well
        lightColor: PlatinumTokens.bevelLight
        darkColor: PlatinumTokens.bevelDark
    }

    PlatinumIcon {
        anchors.centerIn: parent
        visible: root.checked
        name: "check"
        size: 10
        color: root.enabled ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
    }
}
