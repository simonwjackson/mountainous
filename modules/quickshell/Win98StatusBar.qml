pragma ComponentBehavior: Bound

import QtQuick

// A Win98 status bar: thin sunken panes 2 u apart, 18 u tall for one line.
// With several panes the first takes its text's width, up to 45% of the
// bar, and the rest share what is left. Text wraps to two lines (14-u
// pitch) and then elides, so a long hint grows the bar instead of losing
// its keys.
Item {
    id: root

    property var panes: []             // strings; "&" is literal
    property int maximumLineCount: 2

    readonly property real u: Win98Tokens.u
    readonly property real gap: 2 * u
    readonly property real firstWidth: panes.length > 1
        ? Math.min(Win98Tokens.snap(width * 0.45), Win98Tokens.ceilU(Win98Tokens.textWidth(panes[0], false)) + 8 * u)
        : width
    readonly property real restWidth: panes.length > 1
        ? Math.floor((width - firstWidth - gap * (panes.length - 1)) / (panes.length - 1) / u) * u : 0

    function paneWidth(i) {
        if (i === 0) return root.firstWidth;
        // The last pane takes the remainder, so the bar ends on its edge.
        if (i === root.panes.length - 1) return root.width - root.firstWidth - (root.panes.length - 2) * (root.restWidth + root.gap) - root.gap;
        return root.restWidth;
    }

    readonly property real lineHeight: 14 * u
    property real tallest: lineHeight

    implicitWidth: Win98Tokens.ceilU(Win98Tokens.widest(panes, false)) + 8 * u
    implicitHeight: tallest + 4 * u

    Row {
        spacing: root.gap
        Repeater {
            id: repeater
            model: root.panes

            Item {
                id: pane
                required property string modelData
                required property int index
                width: root.paneWidth(index)
                height: root.height

                Win98Bevel {
                    anchors.fill: parent
                    filled: false
                    variant: "thinSunken"
                }
                Win98Text {
                    id: label
                    x: 4 * root.u
                    y: 2 * root.u    // 2 u padding; the half unit of leading rounds away
                    width: pane.width - 8 * root.u
                    text: pane.modelData
                    accessMarks: false
                    wrap: true
                    lineUnits: 14
                    maximumLineCount: root.maximumLineCount
                    onImplicitHeightChanged: root.measure()
                    Component.onCompleted: root.measure()
                }
            }
        }
    }

    function measure() {
        let h = root.lineHeight;
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item && item.children[1]) h = Math.max(h, Win98Tokens.ceilU(item.children[1].implicitHeight));
        }
        root.tallest = h;
    }
}
