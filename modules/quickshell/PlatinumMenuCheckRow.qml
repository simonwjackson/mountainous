import Hensou as Kit
import QtQuick
import QtQuick.Layouts

// A check box on the menu grid: the box in the gutter, its label on the
// text edge, and optional controls ending on the right edge. A click on
// the box or on the label toggles it.
Item {
    id: root

    property string text: ""
    property bool checked: false
    property real rightInset: Kit.PlatinumTokens.menuRightInset
    default property alias trailing: trailingRow.data
    signal toggled(bool checked)

    Layout.fillWidth: true
    implicitHeight: Kit.PlatinumTokens.menuLine + 4
    implicitWidth: Kit.PlatinumTokens.menuTextLeft + label.implicitWidth + rightInset

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
        x: Kit.PlatinumTokens.menuGutter + (Kit.PlatinumTokens.menuGutterWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        enabled: root.enabled
    }

    Text {
        id: label
        x: Kit.PlatinumTokens.menuTextLeft
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.enabled ? Kit.PlatinumTokens.menuText : Kit.PlatinumTokens.menuTextOff
        font.family: Kit.PlatinumTokens.platinumFont
        font.pixelSize: Kit.PlatinumTokens.platinumText
        font.letterSpacing: Kit.PlatinumTokens.platinumTracking
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: root.rightInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Kit.PlatinumTokens.menuGap
    }
}
