import Quickshell
import QtQuick

// A Win98 window frame: the window bevel (light grey outside, white
// inside), 3 u of face, an 18-u caption with a gradient from the left
// (navy to blue when active, greys when not), a 16-u icon, the bold title
// (elided with three dots), and the caption buttons: help (?) and close
// (×), 5 u apart as the mock draws them (Win98 itself left 2 px). Children go in the body under the caption, with Win98's
// dialog margins (6 u top, 8 u sides and bottom) unless margins is false.
// The frame takes its first child's implicit size unless you size it.
//
// availableHeight (logical px, 0 = no limit) caps the frame: a window
// taller than the room keeps its caption and scrolls its body, with a
// Win98 scroll bar, and keyboard focus moving inside it scrolls the
// focused control into view. A window with lists shrinks them first (it
// reads squeeze, how far its natural height is over the room).
FocusScope {
    id: root

    property string title: ""
    property string iconName: ""
    property bool active: true
    property bool showHelp: false
    property bool showClose: true
    property bool showMinimize: false
    // Drawn in the icon's place instead of iconName (a Fleet host icon).
    property Component iconItem: null
    property bool margins: true
    // Draw a caption button pressed: "", "help" or "close".
    property string showPressed: ""
    // Another appearance's colours (Win98Tokens.palette), for previews.
    property var scheme: null
    readonly property var tokens: scheme || Win98Tokens
    default property alias content: body.data

    // Esc closes the window unless this returns true (it handled Esc).
    function cancel() { return false; }

    signal closeClicked
    signal helpClicked
    signal minimizeClicked
    // A press on the caption icon: Win98 opened the window's control menu.
    signal iconClicked

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property real frame: Win98Tokens.frame * u
    readonly property real captionBottom: frame + Win98Tokens.captionHeight * u + u
    readonly property real marginTop: margins ? 6 * u : 0
    readonly property real marginSide: margins ? 8 * u : 0
    readonly property Item first: body.children.length > 0 ? body.children[0] : null

    property real availableHeight: 0
    // The body's usable width: less the scroll bar while it shows.
    readonly property real bodyWidth: body.width
    readonly property bool scrolls: view.contentHeight > view.height + 0.5
    // A body that stops scrolling (the window reached its full height, as
    // it does just after it maps) shows its top again; a shorter view
    // never stays scrolled past its end.
    onScrollsChanged: if (!scrolls) view.contentY = 0

    implicitWidth: (first ? first.implicitWidth : 100 * u) + 2 * frame + 2 * marginSide
    implicitHeight: captionBottom + marginTop + (first ? first.implicitHeight : 0) + marginSide + frame
    height: availableHeight > 0 ? Math.min(implicitHeight, Math.floor(availableHeight / u) * u) : implicitHeight

    // Keep the focused control in view while the body scrolls.
    Connections {
        target: root.Window.window
        ignoreUnknownSignals: true
        function onActiveFocusItemChanged() { Qt.callLater(root.revealFocus); }
    }
    function revealFocus() {
        const item = root.Window.activeFocusItem;
        let inside = false;
        for (let p = item; p; p = p.parent) if (p === body) { inside = true; break; }
        if (!root.scrolls || !inside) return;
        const top = item.mapToItem(view.contentItem, 0, 0).y;
        let y = view.contentY;
        if (top < y) y = top - 2 * u;
        else if (top + item.height > y + view.height) y = top + item.height - view.height + 2 * u;
        view.contentY = Math.max(0, Math.min(view.contentHeight - view.height, Win98Tokens.snap(y, u)));
    }

    Win98Bevel {
        anchors.fill: parent
        variant: "window"
        scheme: root.scheme
    }

    Rectangle {
        id: caption
        x: root.frame; y: root.frame
        width: root.width - 2 * root.frame
        height: Win98Tokens.captionHeight * root.u
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.active ? root.tokens.caption1 : root.tokens.inactiveCaption1 }
            GradientStop { position: 1; color: root.active ? root.tokens.caption2 : root.tokens.inactiveCaption2 }
        }

        Win98Icon {
            id: icon
            visible: root.iconName !== "" && !root.iconItem
            x: 3 * root.u
            y: root.u
            name: root.iconName
            color: root.tokens.captionText
        }
        Loader {
            id: iconLoader
            active: root.iconItem !== null
            x: 3 * root.u
            y: root.u
            width: 16 * root.u
            height: 16 * root.u
            sourceComponent: root.iconItem
        }
        MouseArea {
            visible: icon.visible || iconLoader.active
            x: 3 * root.u
            y: root.u
            width: 16 * root.u
            height: 16 * root.u
            onPressed: root.iconClicked()
        }
        Win98Text {
            x: root.iconName !== "" || root.iconItem ? icon.x + 16 * root.u + 3 * root.u : 3 * root.u
            y: 3 * root.u        // 2.5 u, on the unit grid (snap)
            width: Math.max(0, Math.min(implicitWidth, buttons.x - 3 * root.u - x))
            text: root.title
            accessMarks: false
            bold: true
            color: root.active ? root.tokens.captionText : root.tokens.inactiveCaptionText
        }
        Row {
            id: buttons
            x: caption.width - 2 * root.u - width
            y: 2 * root.u
            spacing: 5 * root.u
            Win98CaptionButton {
                visible: root.showMinimize
                objectName: "captionMinimize"
                glyph: "minimize"
                scheme: root.scheme
                showPressed: root.showPressed === "minimize"
                onClicked: root.minimizeClicked()
            }
            Win98CaptionButton {
                visible: root.showHelp
                glyph: "help"
                scheme: root.scheme
                showPressed: root.showPressed === "help"
                onClicked: root.helpClicked()
            }
            Win98CaptionButton {
                visible: root.showClose
                glyph: "close"
                scheme: root.scheme
                showPressed: root.showPressed === "close"
                onClicked: root.closeClicked()
            }
        }
    }

    Flickable {
        id: view
        x: root.frame
        y: root.captionBottom
        width: root.width - 2 * root.frame
        height: Math.max(0, root.height - y - root.frame)
        contentWidth: width
        contentHeight: root.marginTop + (root.first ? root.first.implicitHeight : 0) + root.marginSide
        interactive: false
        clip: true
        onHeightChanged: contentY = Math.max(0, Math.min(contentY, contentHeight - height))
        WheelHandler {
            enabled: root.scrolls
            onWheel: event => view.contentY = Math.max(0, Math.min(view.contentHeight - view.height,
                view.contentY - Math.sign(event.angleDelta.y) * 20 * root.u))
        }

        Item {
            id: body
            x: root.marginSide
            y: root.marginTop
            width: view.width - 2 * root.marginSide - (root.scrolls ? 18 * root.u : 0)
            height: root.first ? root.first.implicitHeight : 0
        }
    }

    Win98ScrollBar {
        visible: root.scrolls
        x: root.width - root.frame - width - root.u
        y: view.y
        height: view.height
        flickable: view
        step: 16 * root.u
    }
}
