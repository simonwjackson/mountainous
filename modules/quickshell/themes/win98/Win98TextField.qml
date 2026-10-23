pragma ComponentBehavior: Bound

import QtQuick

// A Win98 text field: 21 u tall, sunken, white (dark in dark grey), the
// text 4 u in, a 1-u caret that blinks (steady under reduced motion).
// Selected text takes the selection colours. Disabled: face background
// and grey text. The text draws through the same 25 px / scale route as
// Win98Text, so it stays on the grid.
FocusScope {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property alias readOnly: input.readOnly
    property alias maximumLength: input.maximumLength
    property alias input: input
    property string placeholder: ""
    // Draw a steady caret without keyboard focus (galleries).
    property bool showCaret: false

    signal accepted

    readonly property real u: Win98Tokens.u
    readonly property real k: Win98Tokens.textScale

    implicitWidth: 120 * u
    implicitHeight: Win98Tokens.fieldHeight * u
    activeFocusOnTab: enabled

    Win98Bevel {
        anchors.fill: parent
        variant: "field"
        color: root.enabled ? Win98Tokens.win : Win98Tokens.face
    }

    Item {
        id: clipper
        x: 2 * root.u; y: 2 * root.u
        width: root.width - 4 * root.u
        height: root.height - 4 * root.u
        clip: true

        Win98Text {
            visible: input.text === "" && root.placeholder !== ""
            x: 2 * root.u
            y: 2 * root.u
            width: clipper.width - 4 * root.u
            text: root.placeholder
            accessMarks: false
            color: Win98Tokens.gray
        }

        TextInput {
            id: input
            x: 2 * root.u
            y: 2 * root.u
            width: (clipper.width - 4 * root.u) / root.k
            height: Win98Tokens.lineUnits * 2
            transformOrigin: Item.TopLeft
            scale: root.k
            focus: true
            enabled: root.enabled
            clip: false
            renderType: Text.NativeRendering
            color: root.enabled ? Win98Tokens.winText : Win98Tokens.gray
            selectionColor: Win98Tokens.selection
            selectedTextColor: Win98Tokens.selectionText
            selectByMouse: true
            font.family: Win98Tokens.fontFamily
            font.pixelSize: Win98Tokens.fontRaster
            font.hintingPreference: Font.PreferNoHinting
            font.kerning: false
            cursorVisible: root.enabled && (root.activeFocus || root.showCaret)
            onAccepted: root.accepted()

            cursorDelegate: Rectangle {
                id: caret
                width: 2          // 1 u
                height: Win98Tokens.lineUnits * 2
                color: Win98Tokens.winText
                visible: input.cursorVisible && blink.on
                Timer {
                    id: blink
                    property bool on: true
                    interval: 530
                    repeat: true
                    running: input.cursorVisible && !Win98Tokens.reducedMotion && !root.showCaret
                    onRunningChanged: on = true
                    onTriggered: on = !on
                }
            }
        }
    }
}
