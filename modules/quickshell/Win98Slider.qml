pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// A Win98 trackbar.
//
// Horizontal (TBS_BOTTOM, as the Brightness window): 28 u tall, a 4-u
// sunken channel, an 11 x 21 u thumb that points down, ticks below.
// Vertical (TBS_BOTH, as the Win98 tray volume popup): 30 u wide, ticks on
// both sides, a 21 x 11 u rectangular thumb. Ticks: `ticks` marks, every
// fifth one 4 u long, the rest 3 u.
//
// value runs 0..1; a drag or a key emits moved(value) and the owner sets
// value (the slider does not hold its own state). Keys: arrows step by
// stepSize, Page Up/Down by 2 steps, Home/End to the ends. Disabled: no
// thumb, the channel at half strength. Focus: a dotted rectangle 1 u out.
FocusScope {
    id: root

    property int orientation: Qt.Horizontal
    property real value: 0
    property real stepSize: 0.05
    property int ticks: 11
    property bool showFocus: false

    signal moved(real value)

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property bool vertical: orientation === Qt.Vertical
    // Length along the travel, in whole units.
    readonly property int span: Math.max(12, Math.round((vertical ? height : width) / u))
    readonly property real clamped: Math.max(0, Math.min(1, value))
    // The thumb's centre, in units from the start of the travel.
    readonly property int thumbAt: vertical ? Math.round(5 + (1 - clamped) * (span - 11))
                                            : Math.round(5 + clamped * (span - 11))

    implicitWidth: vertical ? 30 * u : 200 * u
    implicitHeight: vertical ? 100 * u : 28 * u
    activeFocusOnTab: enabled

    function request(v) { root.moved(Math.max(0, Math.min(1, Math.round(v / root.stepSize) * root.stepSize))); }

    Keys.onPressed: event => {
        const up = event.key === Qt.Key_Right || event.key === Qt.Key_Up;
        const down = event.key === Qt.Key_Left || event.key === Qt.Key_Down;
        if (up || down) root.request(root.clamped + (up ? 1 : -1) * root.stepSize);
        else if (event.key === Qt.Key_PageUp) root.request(root.clamped + 2 * root.stepSize);
        else if (event.key === Qt.Key_PageDown) root.request(root.clamped - 2 * root.stepSize);
        else if (event.key === Qt.Key_Home) root.request(0);
        else if (event.key === Qt.Key_End) root.request(1);
        else return;
        event.accepted = true;
    }

    Win98Bevel {
        variant: "channel"
        color: Win98Tokens.win
        opacity: root.enabled ? 1 : 0.5
        x: root.vertical ? 13 * root.u : 0
        y: root.vertical ? 0 : 8 * root.u
        width: root.vertical ? 4 * root.u : root.width
        height: root.vertical ? root.height : 4 * root.u
    }

    Repeater {
        model: root.ticks

        Item {
            id: tick
            required property int index
            readonly property int at: Math.round(5 + index * (root.span - 11) / Math.max(1, root.ticks - 1))
            readonly property real len: (index % 5 === 0 ? 4 : 3) * root.u

            Rectangle {
                x: root.vertical ? 0 : tick.at * root.u
                y: root.vertical ? tick.at * root.u : 23 * root.u
                width: root.vertical ? tick.len : root.u
                height: root.vertical ? root.u : tick.len
                color: Win98Tokens.text
            }
            Rectangle {
                visible: root.vertical
                x: root.width - tick.len
                y: tick.at * root.u
                width: tick.len
                height: root.u
                color: Win98Tokens.text
            }
        }
    }

    // Vertical: a rectangular raised thumb.
    Win98Bevel {
        visible: root.enabled && root.vertical
        x: 5 * root.u
        y: (root.thumbAt - 5) * root.u
        width: 21 * root.u
        height: 11 * root.u
        variant: "button"
    }

    // Horizontal: the pointed thumb, drawn pixel by pixel.
    Win98Svg {
        visible: root.enabled && !root.vertical
        x: (root.thumbAt - 5) * root.u
        y: 0
        width: 11 * root.u
        height: 21 * root.u
        svg: {
            const T = Win98Tokens;
            const r = (x, y, w, h, c) => '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" fill="' + c + '"/>';
            let s = '<svg xmlns="http://www.w3.org/2000/svg" width="11" height="21" viewBox="0 0 11 21" shape-rendering="crispEdges">';
            s += r(0, 0, 11, 17, T.face);
            for (let i = 1; i <= 4; i++) s += r(i, 16 + i, 11 - 2 * i, 1, T.face);
            s += r(0, 0, 10, 1, T.hi) + r(0, 0, 1, 17, T.hi);        // outer light
            s += r(1, 1, 8, 1, T.li) + r(1, 1, 1, 16, T.li);         // inner light
            s += r(10, 0, 1, 17, T.dk) + r(9, 1, 1, 16, T.sh);       // right
            for (let i = 1; i <= 4; i++) {
                s += r(i, 16 + i, 1, 1, T.hi);                       // left slope
                s += r(10 - i, 16 + i, 1, 1, T.dk);                  // right slope
                if (i < 4) s += r(9 - i, 16 + i, 1, 1, T.sh);
            }
            s += r(5, 20, 1, 1, T.dk);                               // the point
            return s + '</svg>';
        }
    }

    Win98FocusRect {
        visible: root.enabled && (root.showFocus || root.activeFocus)
        x: -root.u; y: -root.u
        width: root.width + 2 * root.u
        height: root.height + 2 * root.u
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        function at(mouse) {
            const p = root.vertical ? (mouse.y / root.u - 5) / (root.span - 11) : (mouse.x / root.u - 5) / (root.span - 11);
            root.request(root.vertical ? 1 - p : p);
        }
        onPressed: mouse => { root.forceActiveFocus(); at(mouse); }
        onPositionChanged: mouse => { if (pressed) at(mouse); }
    }
}
