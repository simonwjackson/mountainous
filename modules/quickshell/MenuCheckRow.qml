import QtQuick
import QtQuick.Layouts

// A check box on the menu grid: the box in the gutter, its label on the
// text edge, and optional controls ending on the right edge. A click on
// the box or on the label toggles it.
Item {
    id: root

    property string text: ""
    property bool checked: false
    property real rightInset: Theme.menuRightInset
    default property alias trailing: trailingRow.data
    signal toggled(bool checked)

    Layout.fillWidth: true
    implicitHeight: Theme.menuLine + 4
    implicitWidth: Theme.menuTextLeft + label.implicitWidth + rightInset

    MouseArea {
        x: 0
        width: label.x + label.width + 4
        height: parent.height
        enabled: root.enabled
        onPressed: box.down = true
        onReleased: box.down = false
        onCanceled: box.down = false
        onClicked: root.toggled(!root.checked)
    }

    PlatinumCheckBox {
        id: box
        x: Theme.menuGutter + (Theme.menuGutterWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        enabled: root.enabled
    }

    Text {
        id: label
        x: Theme.menuTextLeft
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.enabled ? Theme.menuText : Theme.menuTextOff
        font.family: Theme.platinumFont
        font.pixelSize: Theme.platinumText
        font.letterSpacing: Theme.platinumTracking
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: root.rightInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.menuGap
    }
}
