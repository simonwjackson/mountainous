import QtQuick

// A Win98 window frame: the window bevel (light grey outside, white
// inside), 3 u of face, an 18-u caption with a gradient from the left
// (navy to blue when active, greys when not), a 16-u icon, the bold title
// (elided with three dots), and the caption buttons: help (?) and close
// (×), 2 u apart. Children go in the body under the caption, with Win98's
// dialog margins (6 u top, 8 u sides and bottom) unless margins is false.
// The frame takes its first child's implicit size unless you size it.
FocusScope {
    id: root

    property string title: ""
    property string iconName: ""
    property bool active: true
    property bool showHelp: false
    property bool showClose: true
    property bool margins: true
    // Draw a caption button pressed: "", "help" or "close".
    property string showPressed: ""
    default property alias content: body.data

    signal closeClicked
    signal helpClicked

    readonly property real u: Win98Tokens.u
    readonly property real frame: Win98Tokens.frame * u
    readonly property real captionBottom: frame + Win98Tokens.captionHeight * u + u
    readonly property real marginTop: margins ? 6 * u : 0
    readonly property real marginSide: margins ? 8 * u : 0
    readonly property Item first: body.children.length > 0 ? body.children[0] : null

    implicitWidth: (first ? first.implicitWidth : 100 * u) + 2 * frame + 2 * marginSide
    implicitHeight: captionBottom + marginTop + (first ? first.implicitHeight : 0) + marginSide + frame

    Win98Bevel {
        anchors.fill: parent
        variant: "window"
    }

    Rectangle {
        id: caption
        x: root.frame; y: root.frame
        width: root.width - 2 * root.frame
        height: Win98Tokens.captionHeight * root.u
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.active ? Win98Tokens.caption1 : Win98Tokens.inactiveCaption1 }
            GradientStop { position: 1; color: root.active ? Win98Tokens.caption2 : Win98Tokens.inactiveCaption2 }
        }

        Win98Icon {
            id: icon
            visible: root.iconName !== ""
            x: 3 * root.u
            y: root.u
            name: root.iconName
            color: Win98Tokens.captionText
        }
        Win98Text {
            x: root.iconName !== "" ? icon.x + icon.width + 3 * root.u : 3 * root.u
            y: 3 * root.u        // 2.5 u, on the unit grid (snap)
            width: Math.max(0, Math.min(implicitWidth, buttons.x - 3 * root.u - x))
            text: root.title
            accessMarks: false
            bold: true
            color: root.active ? Win98Tokens.captionText : Win98Tokens.inactiveCaptionText
        }
        Row {
            id: buttons
            x: caption.width - 2 * root.u - width
            y: 2 * root.u
            spacing: 2 * root.u
            Win98CaptionButton {
                visible: root.showHelp
                glyph: "help"
                showPressed: root.showPressed === "help"
                onClicked: root.helpClicked()
            }
            Win98CaptionButton {
                visible: root.showClose
                glyph: "close"
                showPressed: root.showPressed === "close"
                onClicked: root.closeClicked()
            }
        }
    }

    Item {
        id: body
        x: root.frame + root.marginSide
        y: root.captionBottom + root.marginTop
        width: root.width - 2 * root.frame - 2 * root.marginSide
        height: root.height - y - root.frame - root.marginSide
    }
}
