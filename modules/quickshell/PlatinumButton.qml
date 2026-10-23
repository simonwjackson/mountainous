import QtQuick

// A Platinum push button. Buttons that share a role share one width: the
// caller passes the width of the role's longest label (see
// PlatinumMetrics.buttonWidth), so a column of Connect / Disconnect / Pair
// ends on one edge and starts on one edge.
//
// A press sinks the bevel and darkens the face, as Mac OS 8 did. An icon
// button (the × forget box) passes icon instead of text and is square.
//
// The face takes Theme.radiusSmall. The default ring and the focus ring
// sit outside it, so their radii grow by their distance from the face;
// that keeps all three corners concentric at any hair width.
Item {
    id: root

    property string text: ""
    property string icon: ""
    // A fixed width for the role. 0 means the label's own width.
    property real fixedWidth: 0
    // Mac OS's default button: a second ring, the one Enter runs.
    property bool isDefault: false
    // The keyboard's current target, where the bar has none (notification
    // actions). A ring in the highlight colour.
    property bool focused: false
    property bool onBar: false
    property string keyHint: ""
    signal clicked

    readonly property bool hovered: area.containsMouse
    readonly property bool down: area.pressed && area.containsMouse
    readonly property real ring: isDefault ? 2 * Theme.hair : 0

    implicitHeight: (onBar ? 20 : Theme.menuButtonHeight) + 2 * ring
    implicitWidth: (fixedWidth > 0 ? fixedWidth
        : icon !== "" && text === "" ? Theme.menuButtonHeight
        : label.implicitWidth + 20) + 2 * ring
    opacity: 1

    Rectangle {
        visible: root.isDefault
        anchors.fill: parent
        color: "transparent"
        border.width: Theme.hair
        border.color: Theme.menuEdge
        radius: Theme.radiusSmall + root.ring
    }

    Bevel {
        id: face
        anchors.fill: parent
        anchors.margins: root.ring
        radius: Theme.radiusSmall
        sunken: root.down
        bevelled: !root.onBar || Theme.barBevelled
        edgeColor: root.onBar ? Theme.barButtonEdge : Theme.menuEdge
        color: root.down ? Theme.well : root.onBar ? Theme.barButton : Theme.raised
    }

    Rectangle {
        visible: root.focused
        anchors.fill: face
        anchors.margins: -2 * Theme.hair
        color: "transparent"
        radius: Theme.radiusSmall + 2 * Theme.hair
        border.width: 2 * Theme.hair
        border.color: Theme.highlight
    }

    Text {
        id: label
        visible: root.text !== ""
        anchors.centerIn: face
        width: Math.min(implicitWidth, face.width - 8)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.keyHint !== "" ? root.keyHint + "  " + root.text : root.text
        textFormat: Text.PlainText
        color: !root.enabled ? Theme.menuTextOff : root.onBar ? Theme.barText : Theme.menuText
        font.family: Theme.platinumFont
        font.pixelSize: Theme.platinumSmall
        font.letterSpacing: Theme.platinumTracking
    }

    PlatinumIcon {
        visible: root.icon !== ""
        anchors.centerIn: face
        name: root.icon
        size: 8
        color: root.enabled ? Theme.menuText : Theme.menuTextOff
    }

    MouseArea {
        id: area
        anchors.fill: parent
        // The hit area never drops below 28 px tall.
        anchors.topMargin: Math.min(0, (root.height - 28) / 2)
        anchors.bottomMargin: Math.min(0, (root.height - 28) / 2)
        enabled: root.enabled
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
