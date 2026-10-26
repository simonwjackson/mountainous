import QtQuick

// A Platinum edit field: a well sunk one rule, with a black inner edge on
// its top and left, and, while it has the keyboard, Platinum's lavender
// focus ring one rule outside it (Mac OS 8 HIG). The Find menu and the Go
// to Address dialog use it.
FocusScope {
    id: root

    property alias text: input.text
    property alias input: input
    property real fontSize: 13
    // The ring shows while the field has the keyboard, unless a list under
    // it has taken the selection (Go to Address with a page chosen).
    property bool ringed: input.activeFocus
    signal edited(string text)
    // Every key, before the field acts on it; accept it to keep it.
    signal keyPressed(var event)

    readonly property real hair: PlatinumTokens.hair
    readonly property real ring: PlatinumTokens.focusRingWidth

    implicitHeight: 24
    implicitWidth: 160

    Rectangle {
        visible: root.ringed
        x: -root.hair - root.ring
        y: -root.hair - root.ring
        width: root.width + 2 * (root.hair + root.ring)
        height: root.height + 2 * (root.hair + root.ring)
        color: "transparent"
        border.width: root.ring
        border.color: PlatinumTokens.focusRing
    }

    Rectangle {
        anchors.fill: parent
        color: PlatinumTokens.field
    }
    // Sunken: the shade on top and left, the light on bottom and right,
    // then the black inner edge on top and left.
    Rectangle { width: parent.width; height: root.hair; color: PlatinumTokens.bevelDark }
    Rectangle { width: root.hair; height: parent.height; color: PlatinumTokens.bevelDark }
    Rectangle { y: parent.height - root.hair; width: parent.width; height: root.hair; color: PlatinumTokens.bevelLight }
    Rectangle { x: parent.width - root.hair; width: root.hair; height: parent.height; color: PlatinumTokens.bevelLight }
    Rectangle { x: root.hair; y: root.hair; width: parent.width - 2 * root.hair; height: root.hair; color: PlatinumTokens.menuEdge }
    Rectangle { x: root.hair; y: root.hair; width: root.hair; height: parent.height - 2 * root.hair; color: PlatinumTokens.menuEdge }

    TextInput {
        id: input
        focus: true
        x: 7
        width: parent.width - x - 6
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.hair / 2
        clip: true
        color: PlatinumTokens.menuText
        selectionColor: PlatinumTokens.highlight
        selectedTextColor: PlatinumTokens.highlightText
        selectByMouse: true
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: root.fontSize
        font.letterSpacing: PlatinumTokens.platinumTracking
        onTextEdited: root.edited(text)
        Keys.onPressed: function (event) { root.keyPressed(event); }
    }
}
