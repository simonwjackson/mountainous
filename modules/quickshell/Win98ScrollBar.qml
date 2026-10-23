pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// A Win98 scroll bar: two 16-u arrow buttons and a dithered track with a
// raised thumb (at least 8 u long). Vertical by default, 16 u wide.
//
// Give it a Flickable and it drives it: an arrow scrolls one step, the
// track a page, the thumb drags; every position lands on a whole step, so
// rows stay on the unit grid. Without a Flickable, set position (0..1) and
// size (the visible fraction) and handle stepped/paged/dragged yourself.
// With nothing to scroll the arrows grey out and the thumb goes.
Item {
    id: root

    property int orientation: Qt.Vertical
    property Flickable flickable: null
    property real step: Win98Tokens.listRow * root.u   // logical px per arrow
    property real position: 0
    property real size: 1
    // "", "back", "forward" or "thumb": draw that part pressed.
    property string showPressed: ""

    signal stepped(int direction)
    signal paged(int direction)
    signal dragged(real position)

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property bool vertical: orientation === Qt.Vertical
    readonly property real length: vertical ? height : width
    readonly property real range: flickable ? (vertical ? flickable.contentHeight - flickable.height : flickable.contentWidth - flickable.width) : 0
    readonly property real shownPosition: flickable ? (range > 0 ? (vertical ? flickable.contentY : flickable.contentX) / range : 0) : position
    readonly property real shownSize: flickable ? (range > 0 ? (vertical ? flickable.height / flickable.contentHeight : flickable.width / flickable.contentWidth) : 1) : size
    readonly property bool active: enabled && shownSize < 1
    readonly property real track: Math.max(0, length - 2 * Win98Tokens.scrollBar * u)
    readonly property real thumbLength: Math.max(8 * u, Win98Tokens.snap(track * Math.min(1, shownSize), root.u))
    readonly property real thumbAt: Win98Tokens.snap((track - thumbLength) * Math.max(0, Math.min(1, shownPosition)), root.u)
    property string pressedPart: ""

    implicitWidth: vertical ? Win98Tokens.scrollBar * u : 100 * u
    implicitHeight: vertical ? 100 * u : Win98Tokens.scrollBar * u

    function moveTo(px) {
        if (!flickable || range <= 0) return;
        const v = Math.max(0, Math.min(range, Math.round(px / root.step) * root.step));
        const snapped = Math.min(v, root.range);
        if (vertical) flickable.contentY = snapped; else flickable.contentX = snapped;
    }
    function current() { return flickable ? (vertical ? flickable.contentY : flickable.contentX) : 0; }
    function doStep(d) { root.stepped(d); root.moveTo(root.current() + d * root.step); }
    function doPage(d) {
        root.paged(d);
        const view = flickable ? (vertical ? flickable.height : flickable.width) : 0;
        root.moveTo(root.current() + d * Math.max(root.step, view - root.step));
    }

    component Arrow: Item {
        id: arrow
        property string part: "back"
        readonly property bool down: root.showPressed === part || root.pressedPart === part
        width: Win98Tokens.scrollBar * root.u
        height: width
        Win98Bevel {
            anchors.fill: parent
            variant: arrow.down ? "flatPressed" : "button"
        }
        Win98Icon {
            id: glyph
            name: root.vertical ? (arrow.part === "back" ? "arrow-up" : "arrow-down")
                                : (arrow.part === "back" ? "arrow-left" : "arrow-right")
            color: root.active ? Win98Tokens.text : Win98Tokens.gray
            x: Win98Tokens.snap((parent.width - width) / 2, root.u) + (arrow.down ? root.u : 0)
            y: Win98Tokens.snap((parent.height - height) / 2, root.u) + (arrow.down ? root.u : 0)
        }
        // Disabled glyphs carry the white emboss, as disabled text does.
        Win98Icon {
            visible: !root.active && Win98Tokens.emboss.a > 0
            z: -1
            name: glyph.name
            color: Win98Tokens.emboss
            x: glyph.x + root.u; y: glyph.y + root.u
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.active
            onPressed: { root.pressedPart = arrow.part; root.doStep(arrow.part === "back" ? -1 : 1); repeat.start(); }
            onReleased: { root.pressedPart = ""; repeat.stop(); }
            Timer {
                id: repeat
                interval: 50
                repeat: true
                triggeredOnStart: false
                onTriggered: root.doStep(arrow.part === "back" ? -1 : 1)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Win98Tokens.face
    }

    Item {
        id: trackArea
        x: root.vertical ? 0 : Win98Tokens.scrollBar * root.u
        y: root.vertical ? Win98Tokens.scrollBar * root.u : 0
        width: root.vertical ? root.width : root.track
        height: root.vertical ? root.track : root.height

        Win98Dither {
            anchors.fill: parent
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.active
            onPressed: mouse => {
                const at = root.vertical ? mouse.y : mouse.x;
                root.doPage(at < root.thumbAt ? -1 : 1);
            }
        }
        Win98Bevel {
            visible: root.active
            variant: "window"
            x: root.vertical ? 0 : root.thumbAt
            y: root.vertical ? root.thumbAt : 0
            width: root.vertical ? root.width : root.thumbLength
            height: root.vertical ? root.thumbLength : root.height

            MouseArea {
                anchors.fill: parent
                property real grab: 0
                property real start: 0
                onPressed: mouse => {
                    const p = mapToItem(trackArea, mouse.x, mouse.y);
                    grab = root.vertical ? p.y : p.x;
                    start = root.thumbAt;
                }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const p = mapToItem(trackArea, mouse.x, mouse.y);
                    const free = root.track - root.thumbLength;
                    const pos = free > 0 ? Math.max(0, Math.min(1, (start + (root.vertical ? p.y : p.x) - grab) / free)) : 0;
                    root.dragged(pos);
                    root.moveTo(pos * root.range);
                }
            }
        }
    }

    Arrow { part: "back" }
    Arrow {
        part: "forward"
        x: root.vertical ? 0 : root.width - width
        y: root.vertical ? root.height - height : 0
    }
}
